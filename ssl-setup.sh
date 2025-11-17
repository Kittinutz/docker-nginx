#!/bin/bash

# SSL Certificate Management Script for Docker Nginx + Certbot
# This script manages SSL certificates and switches nginx configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found. Please copy .env.example to .env and configure it.${NC}"
    exit 1
fi

# Check required variables
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}Error: DOMAIN and EMAIL must be set in .env file${NC}"
    exit 1
fi

echo -e "${BLUE}=== SSL Certificate Management for $DOMAIN ===${NC}"

# Function to enable challenge mode (HTTP only)
enable_challenge_mode() {
    echo -e "${YELLOW}Switching to SSL challenge mode...${NC}"
    
    # Disable HTTPS config and enable challenge config
    if [ -f "nginx/conf.d/https-proxy.conf" ]; then
        mv "nginx/conf.d/https-proxy.conf" "nginx/conf.d/https-proxy.conf.disabled" 2>/dev/null || true
    fi
    
    if [ -f "nginx/conf.d/ssl-challenge.conf.disabled" ]; then
        mv "nginx/conf.d/ssl-challenge.conf.disabled" "nginx/conf.d/ssl-challenge.conf"
    fi
    
    # Replace domain placeholder in challenge config
    envsubst '${DOMAIN}' < nginx/conf.d/ssl-challenge.conf > nginx/conf.d/ssl-challenge.conf.tmp
    mv nginx/conf.d/ssl-challenge.conf.tmp nginx/conf.d/ssl-challenge.conf
    
    # Update environment
    sed -i '' 's/SSL_MODE=ssl/SSL_MODE=challenge/' .env 2>/dev/null || true
    
    echo -e "${GREEN}Challenge mode enabled. Restarting nginx...${NC}"
    docker compose restart nginx
}

# Function to enable SSL mode (HTTPS)
enable_ssl_mode() {
    echo -e "${YELLOW}Switching to SSL mode...${NC}"
    
    # Check if certificates exist
    if [ ! -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
        echo -e "${RED}Error: SSL certificates not found for $DOMAIN${NC}"
        echo -e "${YELLOW}Please run: $0 obtain${NC}"
        exit 1
    fi
    
    # Disable challenge config and enable HTTPS config
    if [ -f "nginx/conf.d/ssl-challenge.conf" ]; then
        mv "nginx/conf.d/ssl-challenge.conf" "nginx/conf.d/ssl-challenge.conf.disabled"
    fi
    
    if [ -f "nginx/conf.d/https-proxy.conf.disabled" ]; then
        mv "nginx/conf.d/https-proxy.conf.disabled" "nginx/conf.d/https-proxy.conf"
    fi
    
    # Replace domain placeholder in HTTPS config
    envsubst '${DOMAIN}' < nginx/conf.d/https-proxy.conf > nginx/conf.d/https-proxy.conf.tmp
    mv nginx/conf.d/https-proxy.conf.tmp nginx/conf.d/https-proxy.conf
    
    # Update environment
    sed -i '' 's/SSL_MODE=challenge/SSL_MODE=ssl/' .env 2>/dev/null || true
    
    echo -e "${GREEN}SSL mode enabled. Restarting nginx...${NC}"
    docker compose restart nginx
}

# Function to obtain SSL certificate
obtain_certificate() {
    echo -e "${YELLOW}Obtaining SSL certificate for $DOMAIN...${NC}"
    
    # Enable challenge mode first
    enable_challenge_mode
    
    # Wait for nginx to be ready
    sleep 5
    
    # Obtain certificate
    docker compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d $DOMAIN \
        -d www.$DOMAIN
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Certificate obtained successfully!${NC}"
        echo -e "${YELLOW}Switching to SSL mode...${NC}"
        enable_ssl_mode
    else
        echo -e "${RED}Failed to obtain certificate${NC}"
        exit 1
    fi
}

# Function to renew certificate
renew_certificate() {
    echo -e "${YELLOW}Renewing SSL certificate...${NC}"
    
    docker compose run --rm certbot renew
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Certificate renewed successfully!${NC}"
        echo -e "${YELLOW}Reloading nginx...${NC}"
        docker compose exec nginx nginx -s reload
    else
        echo -e "${RED}Failed to renew certificate${NC}"
        exit 1
    fi
}

# Function to check certificate status
check_certificate() {
    echo -e "${YELLOW}Checking certificate status for $DOMAIN...${NC}"
    
    docker compose run --rm certbot certificates
    
    if [ -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
        echo -e "${GREEN}Certificate files found:${NC}"
        echo "  - Certificate: certbot/conf/live/$DOMAIN/fullchain.pem"
        echo "  - Private Key: certbot/conf/live/$DOMAIN/privkey.pem"
        echo "  - Chain: certbot/conf/live/$DOMAIN/chain.pem"
        
        # Check expiry
        echo -e "${BLUE}Certificate details:${NC}"
        openssl x509 -in "certbot/conf/live/$DOMAIN/fullchain.pem" -text -noout | grep -E "Subject:|Not After" || true
    else
        echo -e "${YELLOW}No certificate found for $DOMAIN${NC}"
    fi
}

# Function to show status
show_status() {
    echo -e "${BLUE}=== Current Status ===${NC}"
    echo "Domain: $DOMAIN"
    echo "Email: $EMAIL"
    echo "SSL Mode: ${SSL_MODE:-challenge}"
    
    echo -e "\n${BLUE}=== Active Nginx Config ===${NC}"
    if [ -f "nginx/conf.d/ssl-challenge.conf" ]; then
        echo "✓ Challenge mode (HTTP + ACME)"
    fi
    
    if [ -f "nginx/conf.d/https-proxy.conf" ]; then
        echo "✓ SSL mode (HTTPS)"
    fi
    
    echo -e "\n${BLUE}=== Docker Services ===${NC}"
    docker compose ps
}

# Main menu
case "$1" in
    obtain)
        obtain_certificate
        ;;
    renew)
        renew_certificate
        ;;
    check)
        check_certificate
        ;;
    challenge)
        enable_challenge_mode
        ;;
    ssl)
        enable_ssl_mode
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {obtain|renew|check|challenge|ssl|status}"
        echo ""
        echo "Commands:"
        echo "  obtain     - Obtain new SSL certificate and enable HTTPS"
        echo "  renew      - Renew existing SSL certificate"
        echo "  check      - Check certificate status and details"
        echo "  challenge  - Switch to challenge mode (HTTP only)"
        echo "  ssl        - Switch to SSL mode (HTTPS)"
        echo "  status     - Show current configuration status"
        echo ""
        echo "Example workflow:"
        echo "  1. $0 status          # Check current status"
        echo "  2. $0 challenge       # Enable challenge mode"
        echo "  3. $0 obtain          # Obtain SSL certificate"
        echo "  4. $0 renew           # Renew certificate (later)"
        exit 1
        ;;
esac

echo -e "${GREEN}Done!${NC}"