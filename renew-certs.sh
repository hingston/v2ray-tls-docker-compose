#!/bin/bash
set -e

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
fi

# Run acme.sh renew
docker-compose run --rm acme --renew --dns dns_cf -d ${DOMAIN} \
    --key-file /certs/private.key \
    --cert-file /certs/cert.crt \
    --fullchain-file /certs/fullchain.crt \
    --server letsencrypt

# Restart V2Ray to use the new certificates
docker-compose restart v2ray

echo "Certificates renewed and V2Ray restarted successfully."