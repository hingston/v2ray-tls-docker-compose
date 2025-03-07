#!/bin/bash
set -e

echo "========== V2Ray Security Check =========="
echo "Checking system and configuration for security issues..."

# Load environment variables
source .env

# Check if certificates are valid
echo -n "Checking SSL certificates: "
if [ -f "./certs/fullchain.crt" ] && openssl x509 -checkend 2592000 -noout -in ./certs/fullchain.crt; then
    echo "OK (Valid for at least 30 days)"
else
    echo "WARNING - Certificate is missing or will expire soon"
    echo "Running certificate renewal..."
    ./renew-certs.sh
fi

# Check if Cloudflare proxy is enabled (using API)
echo -n "Checking Cloudflare proxy status: "
CF_STATUS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$DOMAIN" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json")

PROXIED=$(echo "$CF_STATUS" | grep -o '"proxied":true' | wc -l)
if [ "$PROXIED" -gt 0 ]; then
    echo "OK (Cloudflare proxy is enabled)"
else
    echo "WARNING - Cloudflare proxy may not be enabled"
    echo "Consider enabling proxy in Cloudflare to hide your server IP"
fi

# Check Docker container status
echo -n "Checking container status: "
if docker-compose ps | grep -q "v2ray.*Up"; then
    echo "OK (V2Ray container is running)"
else
    echo "ERROR - V2Ray container is not running"
    echo "Attempting to restart..."
    docker-compose up -d v2ray
fi

# Check for any exposed ports
echo -n "Checking for unnecessary exposed ports: "
EXPOSED_PORTS=$(netstat -tulpn 2>/dev/null | grep LISTEN | grep -v "127.0.0.1\|::1" | awk '{print $4}' | awk -F: '{print $NF}')
EXPECTED_PORTS="443"
UNEXPECTED_PORTS=0

for PORT in $EXPOSED_PORTS; do
    if ! echo "$EXPECTED_PORTS" | grep -q "$PORT"; then
        echo "WARNING - Unexpected port open: $PORT"
        UNEXPECTED_PORTS=1
    fi
done

if [ "$UNEXPECTED_PORTS" -eq 0 ]; then
    echo "OK (No unexpected ports open)"
fi

# Check firewall status
echo -n "Checking firewall status: "
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo "OK (Firewall is active)"
else
    echo "WARNING - Firewall may not be enabled"
    echo "Consider enabling ufw or another firewall:"
    echo "sudo ufw allow 443/tcp && sudo ufw enable"
fi

# Check V2Ray config file
echo -n "Checking V2Ray configuration: "
if docker-compose exec v2ray v2ray test -c /etc/v2ray/config.json &> /dev/null; then
    echo "OK (Configuration is valid)"
else
    echo "ERROR - Configuration issue detected"
    echo "Please check your V2Ray configuration"
fi

echo "========== Security Check Complete =========="
echo "Run this script periodically to ensure your server remains secure."