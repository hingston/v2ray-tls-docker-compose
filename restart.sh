#!/bin/bash
set -e

echo "Rebuilding and restarting V2Ray service..."
docker-compose down
docker-compose up -d --build v2ray

echo "V2Ray service has been restarted."
echo "To check the logs, run: docker-compose logs -f v2ray"