FROM teddysun/xray:latest

# Create log directory
RUN mkdir -p /var/log/xray && \
    chmod 755 /var/log/xray

# Add custom entrypoint script to handle configuration
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["run", "-c", "/etc/xray/config.json"]