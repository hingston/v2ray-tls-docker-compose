FROM v2fly/v2fly-core:latest

# Create log directory
RUN mkdir -p /var/log/v2ray && \
    chmod 755 /var/log/v2ray

# Add custom entrypoint script to handle configuration
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["run", "-c", "/etc/v2ray/config.json"]