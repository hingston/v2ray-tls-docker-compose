#!/bin/sh
set -e

# Wait for certificates to be available
while [ ! -f /certs/fullchain.crt ] || [ ! -f /certs/private.key ]; do
  echo "Waiting for certificates to be available..."
  sleep 5
done

echo "Certificates found, starting Xray..."

# Execute the xray command with the provided arguments
exec xray "$@"