#!/bin/bash

# Certbot SSL certificate management script

# Configuration
DOMAIN="investment.dzabattoir.com"
EMAIL="knightza94@gmail.com"
WEBROOT_PATH="/var/www/certbot"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting SSL certificate management...${NC}"

# Function to obtain initial certificate
obtain_certificate() {
    echo -e "${YELLOW}Obtaining SSL certificate for ${DOMAIN}...${NC}"
    
    docker compose run --rm certbot certonly \
        --webroot \
        --webroot-path=$WEBROOT_PATH \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        -d $DOMAIN \
        -d www.$DOMAIN
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Certificate obtained successfully!${NC}"
        echo -e "${YELLOW}Reloading Nginx...${NC}"
        docker compose exec nginx nginx -s reload
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
        echo -e "${YELLOW}Reloading Nginx...${NC}"
        docker compose exec nginx nginx -s reload
    else
        echo -e "${RED}Failed to renew certificate${NC}"
        exit 1
    fi
}

# Function to check certificate status
check_certificate() {
    echo -e "${YELLOW}Checking certificate status...${NC}"
    
    docker compose run --rm certbot certificates
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
    *)
        echo "Usage: $0 {obtain|renew|check}"
        echo "  obtain - Obtain new SSL certificate"
        echo "  renew  - Renew existing SSL certificate"
        echo "  check  - Check certificate status"
        exit 1
        ;;
esac