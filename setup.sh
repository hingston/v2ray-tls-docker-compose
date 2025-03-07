#!/bin/bash
set -e

# Check if running with root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Default values
DEFAULT_DOMAIN="example.com"
DEFAULT_CF_EMAIL=""
DEFAULT_CF_TOKEN=""
DEFAULT_CF_ACCOUNT_ID=""
DEFAULT_CF_ZONE_ID=""

# Parse command line arguments
DOMAIN=${1:-$DEFAULT_DOMAIN}

# Prompt for Cloudflare credentials if not provided
read -p "Enter your Cloudflare email [$DEFAULT_CF_EMAIL]: " CF_EMAIL
CF_EMAIL=${CF_EMAIL:-$DEFAULT_CF_EMAIL}

read -p "Enter your Cloudflare API token [$DEFAULT_CF_TOKEN]: " CF_TOKEN
CF_TOKEN=${CF_TOKEN:-$DEFAULT_CF_TOKEN}

read -p "Enter your Cloudflare Account ID [$DEFAULT_CF_ACCOUNT_ID]: " CF_ACCOUNT_ID
CF_ACCOUNT_ID=${CF_ACCOUNT_ID:-$DEFAULT_CF_ACCOUNT_ID}

read -p "Enter your Cloudflare Zone ID for $DOMAIN [$DEFAULT_CF_ZONE_ID]: " CF_ZONE_ID
CF_ZONE_ID=${CF_ZONE_ID:-$DEFAULT_CF_ZONE_ID}

# Generate a random UUID for V2Ray
UUID=$(cat /proc/sys/kernel/random/uuid)

# Create necessary directories
mkdir -p config certs acme logs/v2ray

# Create .env file
cat > .env << EOF
DOMAIN=$DOMAIN
CF_TOKEN=$CF_TOKEN
CF_ACCOUNT_ID=$CF_ACCOUNT_ID
CF_ZONE_ID=$CF_ZONE_ID
CF_EMAIL=$CF_EMAIL
UUID=$UUID
EOF

# Process the config template
sed -e "s/{{UUID}}/$UUID/g" -e "s/{{DOMAIN}}/$DOMAIN/g" config/config.json.template > config/config.json

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
    echo "Docker and/or Docker Compose not found. Installing..."
    apt-get update
    apt-get install -y docker.io docker-compose
    systemctl enable docker
    systemctl start docker
fi

# Get server IP address
SERVER_IPV4=$(curl -s https://api.ipify.org || curl -s http://ifconfig.me)
echo "Detected IPv4 address: $SERVER_IPV4"

# Ask user if they want to automatically create DNS records in Cloudflare
read -p "Do you want to automatically create DNS records in Cloudflare? (y/n): " create_dns
if [ "$create_dns" = "y" ]; then
    echo "Creating DNS records..."
    
    # Create A record for IPv4
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{
            \"type\":\"A\",
            \"name\":\"$DOMAIN\",
            \"content\":\"$SERVER_IPV4\",
            \"ttl\":120,
            \"proxied\":true
        }"
    
    echo "DNS records created."
fi

# Register acme.sh account first
echo "Registering acme.sh account..."
docker-compose run --rm acme --register-account -m "$CF_EMAIL"

# Start acme container to issue certificates
echo "Obtaining certificates..."
docker-compose up -d acme
sleep 15  # Give more time for certificates to be issued

# Check if certificates were created
if [ ! -f "./certs/fullchain.crt" ] || [ ! -f "./certs/private.key" ]; then
    echo "Certificates were not created. Check the acme.sh logs."
    docker-compose logs acme
    
    # Try one more time with force issue
    echo "Trying again with force issue..."
    docker-compose run --rm acme --force --issue --dns dns_cf -d ${DOMAIN} \
      --key-file /certs/private.key \
      --cert-file /certs/cert.crt \
      --fullchain-file /certs/fullchain.crt \
      --server letsencrypt
      
    sleep 15
    
    # Check again
    if [ ! -f "./certs/fullchain.crt" ] || [ ! -f "./certs/private.key" ]; then
        echo "Certificate issuance failed again. Please check your configuration."
        exit 1
    fi
fi

# Rebuild and start all services
docker-compose up -d --build

# Generate client configuration for Shadowrocket
CLIENT_CONFIG=$(cat <<EOF
{
  "v": "2",
  "ps": "V2Ray-$(hostname)",
  "add": "$DOMAIN",
  "port": "443",
  "id": "$UUID",
  "aid": "0",
  "net": "tcp",
  "type": "none",
  "host": "",
  "path": "",
  "tls": "tls"
}
EOF
)

# Convert to base64 for VMess URL
VMESS_URL="vmess://$(echo $CLIENT_CONFIG | base64 -w 0)"

echo "========================================================"
echo "V2Ray server has been set up successfully!"
echo "========================================================"
echo "Server domain: $DOMAIN"
echo "UUID: $UUID"
echo ""
echo "VMess URL for clients like Shadowrocket:"
echo $VMESS_URL
echo ""
echo "To add to clients manually, use these details:"
echo "Protocol: VMess"
echo "Server: $DOMAIN"
echo "Port: 443"
echo "UUID: $UUID"
echo "AlterID: 0"
echo "Security: auto"
echo "Network: tcp"
echo "TLS: enabled"
echo "========================================================"

# Instructions for Cloudflare proxy setup
echo "Don't forget to set up Cloudflare as follows:"
echo "1. Make sure your domain's nameservers are set to Cloudflare"
echo "2. In Cloudflare DNS settings, add an A record pointing to your server IP"
echo "3. Enable the proxy (orange cloud) for that record to hide your origin IP"
echo "4. In SSL/TLS settings, set the encryption mode to 'Full (strict)'"
echo "========================================================"