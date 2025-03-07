#!/bin/bash
set -e

echo "This will uninstall V2Ray server and remove all related data."
read -p "Are you sure you want to continue? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Stop and remove containers
docker-compose down

# Remove directories and files
read -p "Do you want to remove all data including certificates? (y/n): " remove_data

if [ "$remove_data" == "y" ]; then
    echo "Removing all data..."
    rm -rf config certs acme .env
    echo "All data has been removed."
else
    echo "Keeping data files. To remove them manually, delete config/, certs/, acme/ directories and .env file."
fi

echo "Uninstallation completed successfully."