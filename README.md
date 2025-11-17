# Docker Nginx + Certbot Setup

This project provides a Docker Compose setup for running Nginx with Let's Encrypt SSL certificates using Certbot.

## Project Structure

```
docker-nginx/
├── docker-compose.yml          # Main Docker Compose configuration
├── ssl-management.sh           # SSL certificate management script
├── nginx/
│   ├── nginx.conf             # Main Nginx configuration
│   └── conf.d/
│       └── default.conf       # Site-specific configuration
├── certbot/
│   ├── www/                   # Webroot for ACME challenges
│   └── conf/                  # Let's Encrypt certificates storage
└── README.md
```

## Quick Start

### 1. Configuration

Before starting, update the following files with your domain information:

**nginx/conf.d/default.conf:**

- Replace `example.com` with your actual domain name

**ssl-management.sh:**

- Replace `DOMAIN="example.com"` with your domain
- Replace `EMAIL="your-email@example.com"` with your email

### 2. Initial Setup

1. Start the services without SSL first:

   ```bash
   docker compose up -d
   ```

2. Obtain SSL certificates:

   ```bash
   ./ssl-management.sh obtain
   ```

3. Restart the services to enable HTTPS:
   ```bash
   docker compose restart nginx
   ```

### 3. SSL Certificate Management

The project includes a convenient script for managing SSL certificates:

- **Obtain new certificate:**

  ```bash
  ./ssl-management.sh obtain
  ```

- **Renew existing certificate:**

  ```bash
  ./ssl-management.sh renew
  ```

- **Check certificate status:**
  ```bash
  ./ssl-management.sh check
  ```

### 4. Automatic Certificate Renewal

To set up automatic certificate renewal, add a cron job:

```bash
# Edit crontab
crontab -e

# Add this line to renew certificates twice daily
0 12,0 * * * cd /path/to/docker-nginx && ./ssl-management.sh renew >/dev/null 2>&1
```

## Services

### Nginx

- **Image:** nginx:alpine
- **Ports:** 80 (HTTP), 443 (HTTPS)
- **Volumes:**
  - `./nginx/conf.d` → `/etc/nginx/conf.d`
  - `./nginx/nginx.conf` → `/etc/nginx/nginx.conf`
  - `./certbot/www` → `/var/www/certbot` (for ACME challenges)
  - `./certbot/conf` → `/etc/nginx/ssl` (for SSL certificates)

### Certbot

- **Image:** certbot/certbot:latest
- **Volumes:**
  - `./certbot/www` → `/var/www/certbot` (webroot for challenges)
  - `./certbot/conf` → `/etc/letsencrypt` (certificate storage)

## Configuration Details

### Nginx Features

- **Security Headers:** X-Frame-Options, X-XSS-Protection, X-Content-Type-Options
- **Gzip Compression:** Enabled for common file types
- **SSL Configuration:** Modern TLS 1.2/1.3 with secure ciphers
- **HSTS:** HTTP Strict Transport Security enabled
- **OCSP Stapling:** Enabled for faster certificate validation

### SSL Configuration

- **Protocols:** TLS 1.2 and 1.3
- **Ciphers:** Modern, secure cipher suite
- **Security:** HSTS, OCSP stapling enabled

## Customization

### Adding Your Application

To serve your own application, you can:

1. **Static Files:** Place them in a `www` directory and mount it to `/var/www/html`
2. **Backend Proxy:** Uncomment and modify the proxy configuration in `default.conf`

Example for adding static files:

```yaml
# Add to nginx service volumes in docker-compose.yml
- ./www:/var/www/html:ro
```

Example for backend proxy:

```nginx
# In nginx/conf.d/default.conf
location /api/ {
    proxy_pass http://backend:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

## Troubleshooting

### Common Issues

1. **Certificate Obtaining Fails:**

   - Ensure your domain points to your server
   - Check that port 80 is accessible from the internet
   - Verify domain and email in configuration files

2. **Nginx Won't Start:**

   - Check configuration syntax: `docker compose exec nginx nginx -t`
   - Ensure certificate files exist before enabling HTTPS

3. **Permission Issues:**
   - Make sure the `ssl-management.sh` script is executable
   - Check volume permissions

### Useful Commands

- **Check Nginx configuration:** `docker compose exec nginx nginx -t`
- **Reload Nginx:** `docker compose exec nginx nginx -s reload`
- **View Nginx logs:** `docker compose logs nginx`
- **View Certbot logs:** `docker compose logs certbot`

## Security Notes

- The setup includes modern security headers and SSL configuration
- Certificates are automatically validated and renewed
- HTTP traffic is redirected to HTTPS
- Consider implementing additional security measures based on your requirements

## License

This project is open source and available under the [MIT License](LICENSE).
