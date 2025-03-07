# V2Ray TLS Docker Compose with Cloudflare Tunnel

A simple Docker Compose setup for running a V2Ray server with TLS and Cloudflare Tunnel, eliminating the need for a public IP address or port forwarding while maintaining strong security.

## Features

- Runs V2Ray with VMess protocol, WebSocket transport, and TLS encryption
- Uses Cloudflare Tunnel to provide secure access without public IP or open ports
- Automatically obtains and renews SSL certificates using acme.sh and Cloudflare DNS verification
- Generates client configuration for apps like Shadowrocket
- Includes security hardening and camouflage features:
  - Uses WebSocket for better compatibility with firewalls
  - Includes decoy website to appear as a legitimate web server
  - Blocks access to private/local IPs
  - Regular security checks and certificate renewal
- Works on Raspberry Pi 5, Ubuntu, and most Linux distributions
- Works on home networks without port forwarding or static IP requirements

## Requirements

- A domain name that you control
- The domain's DNS must be managed by Cloudflare
- A Cloudflare account with access to the Zero Trust dashboard
- A server with Docker and Docker Compose installed (or the script will install them)
- Root access on the server

## Setup Instructions

### 1. Clone this repository

```bash
git clone https://github.com/yourusername/v2ray-tls-docker-compose.git
cd v2ray-tls-docker-compose
```

### 2. Prepare Cloudflare credentials

You'll need the following from your Cloudflare account:
- Email address (for Let's Encrypt certificate registration)
- API Token with DNS:Edit permissions (for certificate verification)
- Account ID
- Zone ID for your domain

These credentials are still needed even with Cloudflare Tunnel because:
1. We need to obtain SSL/TLS certificates for v2ray using DNS verification
2. The certificates allow TLS encryption between the client and your v2ray server
3. This provides an additional layer of security alongside the Cloudflare Tunnel

To find these:
1. Log in to Cloudflare dashboard
2. Go to "My Profile" → "API Tokens" → "Create Token" → Use the "Edit zone DNS" template
3. For Account ID, go to the Cloudflare dashboard and check the URL while on the Account Home page: `https://dash.cloudflare.com/<Account ID>`
4. For Zone ID, go to the overview page for your domain

### 3. Create a Cloudflare Tunnel

1. Log in to the Cloudflare Zero Trust dashboard at https://one.dash.cloudflare.com/ (or https://dash.teams.cloudflare.com/)
2. Navigate to **Networks > Tunnels** and click "Create a tunnel"
3. Give your tunnel a name (e.g., "v2ray-tunnel")
4. For connector type, choose "Cloudflared"
5. **Important**: Copy the Tunnel Token - it should start with "eyJ..." and is relatively long
6. Continue to the "Public Hostname" tab and create a hostname that points to your domain
7. **Critical Service URL Configuration**:
   - Set the service URL to "http://proxy:80"
   - The setup includes a proxy service that handles the HTTP to HTTPS conversion
   - This resolves certificate validation and connection issues

> **Security Note**: The Tunnel Token contains sensitive authentication details. 
> Never share this token or commit it to git. It will be saved in your .env file,
> which is automatically excluded from git by .gitignore.

### 4. Run the setup script

```bash
sudo ./setup.sh yourdomain.com
```

The script will:
- Prompt for your Cloudflare credentials and tunnel token
- Generate a random UUID for V2Ray
- Set up the necessary configuration files
- Install Docker and Docker Compose if needed
- Obtain SSL certificates via Cloudflare DNS validation
- Configure the Cloudflare Tunnel
- Start the V2Ray server
- Generate client configuration details

### 5. Set up automatic maintenance (recommended)

Run the following command to set up automatic certificate renewal and security checks:

```bash
sudo ./setup-cron.sh
```

This will:
- Set up a monthly task to renew your SSL certificates
- Set up a weekly security check to ensure your server remains secure
- Save logs to the logs/ directory

## Client Configuration

After running the setup script, you'll receive:
- A VMess URL that can be imported into clients like Shadowrocket
- Manual configuration details if you prefer to enter them yourself

### Compatible Clients

- iOS: Shadowrocket, Quantumult X
- Android: V2rayNG
- Windows: V2rayN
- macOS: V2rayU, ClashX
- Linux: Qv2ray

## Troubleshooting

If you encounter issues:
- Check the logs: `docker-compose logs v2ray` or `docker-compose logs cloudflared`
- Run the security check script: `./secure-check.sh`
- Make sure your Cloudflare API credentials are correct
- Verify the Cloudflare Tunnel connection status in the Zero Trust Dashboard

### Common Cloudflare Tunnel Issues

1. **"tunnel not found" error**: 
   - Ensure your tunnel token is correct in the .env file
   - Check that the tunnel still exists in your Cloudflare Zero Trust dashboard (Networks > Tunnels)
   - Verify the token hasn't expired (tokens are generally valid for several hours)

2. **Connection issues**:
   ```bash
   # Check Cloudflare Tunnel connection status
   docker-compose logs cloudflared | grep -i "connect"
   
   # If you see "error authenticating", your tunnel token may be invalid
   # If you see "unable to reach origin", v2ray service may not be running
   
   # Restart the Cloudflare Tunnel if needed
   docker-compose restart cloudflared
   ```

3. **Tunnel configuration issues**:
   - Check that your hostname is correctly set up in Cloudflare Zero Trust dashboard
   - In Networks > Tunnels, select your tunnel and go to the "Public Hostname" tab
   - Verify the service URL is set to "https://v2ray:443"
   - Check your domain DNS settings in the main Cloudflare dashboard

4. **Network connectivity issues**:
   - The cloudflared container uses host networking for best connectivity
   - If running in a complex Docker environment, you may need to configure custom Docker networks
   - For advanced setups, you can run cloudflared directly with:
     ```bash
     docker run -d --name cloudflared --network host cloudflare/cloudflared \
       tunnel run --token YOUR_TUNNEL_TOKEN
     ```
   
5. **Cannot access the decoy website or connect via clients**:
   - Verify the tunnel is running and connected: `docker-compose logs cloudflared`
   - Check that your public hostname is properly configured in Cloudflare dashboard
   - Test the connection directly with curl: `curl -v https://yourdomain.com`

6. **Cannot connect using the VMess URL in Shadowrocket**:
   - **Important:** In your Cloudflare Public Hostname configuration, make sure:
     - Service URL is set to "http://proxy:80" (the nginx proxy service)
   - Verify the VMess URL has the correct domain, port, and UUID values
   - Try manually configuring the client with these settings:
     - Server: your domain name
     - Port: 443
     - UUID: [the UUID from your setup]
     - Security: auto
     - Network: ws (WebSocket)
     - TLS: enabled (important)
     - Host: your domain
     - Path: /ws (important)
   - Restart the services: `docker-compose down && docker-compose up -d`
   - Verify that your domain is correctly resolving to Cloudflare IPs: `nslookup yourdomain.com`
   - Check the logs from all services to diagnose issues: `docker-compose logs`

To restart all services after making changes:
```bash
./restart.sh
```

To check for common security issues:
```bash
./secure-check.sh
```

## Security Considerations

- The setup uses TLS to encrypt traffic
- Cloudflare Tunnel provides secure connectivity without exposing ports:
  - No public IP address required
  - No port forwarding needed on your router
  - No exposed ports on your server
  - Works on residential ISPs that block ports or use CGNAT
- Multiple layers of encryption: V2Ray TLS + Cloudflare Tunnel TLS
- HTTP security headers added to make the decoy site appear legitimate
- Private IP access is blocked to prevent potential security issues
- Automatic security checks help maintain server security
- Regular certificate renewal ensures TLS remains valid
- Decoy website makes the server appear as a legitimate web host
- Be careful when sharing your VMess URL as it contains your server details

### About the Decoy Website

The decoy website (nginx container) serves these purposes:

1. **Security through camouflage**: If someone were to inspect your server or run traffic analysis, they would see a normal-looking website.

2. **Normal traffic pattern**: The v2ray configuration is set up to mimic HTTP traffic patterns that would be expected for a regular website.

3. **Is it still needed with Cloudflare Tunnel?** Technically, the decoy website is less critical when using Cloudflare Tunnel because:
   - Your server has no publicly exposed ports
   - Traffic is routed through Cloudflare's network
   
   However, we still recommend keeping it for the following reasons:
   - Adds an additional layer of obfuscation
   - The v2ray configuration references it in the HTTP header camouflage
   - Takes minimal resources and completes the security setup

### Sensitive Files Protection

The following sensitive files are automatically excluded from git in .gitignore:
- `.env` - Contains API keys, credentials, and your Cloudflare Tunnel token
- `certs/` - Contains SSL certificates 
- `cloudflared/*.yml` - Contains Cloudflare Tunnel configuration

Never commit these files to a public repository as they contain sensitive information.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
