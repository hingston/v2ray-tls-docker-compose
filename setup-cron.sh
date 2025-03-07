#!/bin/bash
set -e

echo "Setting up automated maintenance tasks..."

# Get the absolute path to the current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create a temporary file for crontab
TEMP_CRON=$(mktemp)

# Get existing crontab
crontab -l > "$TEMP_CRON" 2>/dev/null || echo "# V2Ray Maintenance Tasks" > "$TEMP_CRON"

# Add certificate renewal job (once a month)
if ! grep -q "renew-certs.sh" "$TEMP_CRON"; then
    echo "# Renew V2Ray SSL certificates monthly" >> "$TEMP_CRON"
    echo "0 0 1 * * cd ${SCRIPT_DIR} && ./renew-certs.sh >> ${SCRIPT_DIR}/logs/cron.log 2>&1" >> "$TEMP_CRON"
    echo "Certificate renewal job added."
fi

# Add security check job (once a week)
if ! grep -q "secure-check.sh" "$TEMP_CRON"; then
    echo "# Run security checks weekly" >> "$TEMP_CRON"
    echo "0 0 * * 0 cd ${SCRIPT_DIR} && ./secure-check.sh >> ${SCRIPT_DIR}/logs/cron.log 2>&1" >> "$TEMP_CRON"
    echo "Security check job added."
fi

# Install the new crontab
crontab "$TEMP_CRON"
rm "$TEMP_CRON"

echo "Cron jobs have been set up successfully."
echo "- Certificates will be renewed automatically on the 1st day of each month"
echo "- Security checks will run every Sunday"
echo "- Logs will be saved to ${SCRIPT_DIR}/logs/cron.log"

# Create the log directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"

echo "Setup complete."