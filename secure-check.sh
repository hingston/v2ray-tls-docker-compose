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

# Check if CLOUDFLARE_TUNNEL_TOKEN is in .env
echo -n "Checking Cloudflare Tunnel token: "
if grep -q "CLOUDFLARE_TUNNEL_TOKEN" .env; then
    echo "OK (Tunnel token found in .env)"
else
    echo "ERROR - No tunnel token found in .env"
    echo "Please add your Cloudflare Tunnel token to .env file:"
    echo "CLOUDFLARE_TUNNEL_TOKEN=your_token_here"
fi

# Check if Cloudflare Tunnel is running
echo -n "Checking Cloudflare Tunnel status: "
if docker-compose ps | grep -q "cloudflared.*Up"; then
    echo "OK (Cloudflare Tunnel is running)"
else
    echo "ERROR - Cloudflare Tunnel is not running"
    echo "Attempting to restart..."
    docker-compose up -d cloudflared
fi

# Check Cloudflare Tunnel logs for connectivity issues
echo -n "Checking Cloudflare Tunnel connectivity: "
if docker-compose logs --tail=50 cloudflared | grep -q "Connection.*registered"; then
    echo "OK (Tunnel successfully connected to Cloudflare)"
else 
    echo "WARNING - Tunnel connectivity issues detected"
    echo "Check Cloudflare Tunnel logs for details:"
    echo "docker-compose logs cloudflared"
fi

# Check Docker container status
echo -n "Checking V2Ray container status: "
if docker-compose ps | grep -q "v2ray.*Up"; then
    echo "OK (V2Ray container is running)"
else
    echo "ERROR - V2Ray container is not running"
    echo "Attempting to restart..."
    docker-compose up -d v2ray
fi

# Since we're using Cloudflare Tunnel, we don't need exposed ports
echo -n "Checking for unnecessary exposed ports: "
EXPOSED_PORTS=$(netstat -tulpn 2>/dev/null | grep LISTEN | grep -v "127.0.0.1\|::1" | awk '{print $4}' | awk -F: '{print $NF}')
UNEXPECTED_PORTS=0

for PORT in $EXPOSED_PORTS; do
    echo "WARNING - Unexpected port open: $PORT"
    UNEXPECTED_PORTS=1
done

if [ "$UNEXPECTED_PORTS" -eq 0 ]; then
    echo "OK (No exposed ports, as expected with Cloudflare Tunnel)"
fi

# Check firewall status
echo -n "Checking firewall status: "
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo "OK (Firewall is active)"
else
    echo "WARNING - Firewall may not be enabled"
    echo "Consider enabling ufw or another firewall for additional security"
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