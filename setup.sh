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

# Generate a random UUID for Xray
UUID=$(cat /proc/sys/kernel/random/uuid)

# Create necessary directories
mkdir -p config certs acme logs/xray cloudflared

# Setup Cloudflare Tunnel
echo "Setting up Cloudflare Tunnel..."
echo "You'll need to create a Cloudflare Tunnel in your Cloudflare Zero Trust dashboard."
echo "1. Go to https://dash.teams.cloudflare.com/ and sign in"
echo "2. Navigate to Access > Tunnels and click 'Create a tunnel'"
echo "3. Give your tunnel a name (e.g., 'xray-tunnel')"
echo "4. You'll need to download the credentials file and get the Tunnel ID"
echo ""

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

# Setup Cloudflare Tunnel with token
echo "Setting up Cloudflare Tunnel with token..."
echo "You'll need the Tunnel Token from your Cloudflare Zero Trust dashboard."
echo "1. In the Cloudflare Zero Trust dashboard (https://one.dash.cloudflare.com/)"
echo "2. Navigate to Networks > Tunnels"
echo "3. Create a new tunnel with a name (e.g., 'xray-tunnel')"
echo "4. Copy the tunnel token (starts with 'eyJ...')"
echo "5. Set up a Public Hostname pointing to 'http://proxy:80'"
echo ""
read -p "Enter your Cloudflare Tunnel Token: " CLOUDFLARE_TUNNEL_TOKEN

# Add tunnel token to .env file
echo "CLOUDFLARE_TUNNEL_TOKEN=$CLOUDFLARE_TUNNEL_TOKEN" >> .env

# Important note for cloudflare tunnel configuration
echo ""
echo "IMPORTANT: When setting up your Public Hostname in Cloudflare Zero Trust Dashboard:"
echo "1. For the service URL, use 'http://proxy:80'"
echo "2. The proxy service will handle the HTTP to HTTPS conversion"
echo ""

# Rebuild and start all services
docker-compose up -d --build

# Generate VLESS URL
VLESS_URL="vless://$UUID@$DOMAIN:443?type=ws&security=tls&path=%2Fws&host=$DOMAIN&sni=$DOMAIN#Xray-$(hostname)"

echo "========================================================"
echo "Xray server has been set up successfully with Cloudflare Tunnel!"
echo "========================================================"
echo "Server domain: $DOMAIN"
echo "UUID: $UUID"
echo ""
echo "VLESS URL for clients:"
echo $VLESS_URL
echo ""
echo "To add to clients manually, use these details:"
echo "Protocol: VLESS"
echo "Server: $DOMAIN"
echo "Port: 443"
echo "UUID: $UUID"
echo "Flow: xtls-rprx-direct"
echo "Encryption: none"
echo "Network: ws"
echo "Path: /ws"
echo "TLS: enabled"
echo "========================================================"

echo "Cloudflare Tunnel has been configured:"
echo "1. Your server is now accessible via Cloudflare Tunnel with no open ports"
echo "2. Traffic is encrypted and secured without needing a public IP"
echo "3. The Cloudflare Tunnel automatically manages DNS records"
echo "4. No port forwarding is required on your router"
echo "========================================================="