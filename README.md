# V2Ray TLS Docker Compose

A simple Docker Compose setup for running a V2Ray server with TLS, using Cloudflare DNS for domain verification and optional proxy to hide the server's original IP address.

## Features

- Runs V2Ray with VMess protocol and TLS encryption
- Automatically obtains and renews SSL certificates using acme.sh and Cloudflare DNS verification
- Supports Cloudflare proxy to hide the origin server IP
- Automatically creates DNS records in Cloudflare (optional)
- Generates client configuration for apps like Shadowrocket
- Includes security hardening and camouflage features:
  - Disguises traffic as normal HTTPS web traffic
  - Includes decoy website to appear as a legitimate web server
  - Blocks access to private/local IPs
  - Regular security checks and certificate renewal
- Works on Raspberry Pi 5, Ubuntu, and most Linux distributions

## Requirements

- A domain name that you control
- The domain's DNS must be managed by Cloudflare
- A server with Docker and Docker Compose installed (or the script will install them)
- Root access on the server

## Setup Instructions

### 1. Clone this repository

```bash
git clone https://github.com/yourusername/v2ray-tls-docker-compose.git
cd v2ray-tls-docker-compose
```

### 2. Prepare Cloudflare API credentials

You'll need the following from your Cloudflare account:
- Email address (for Let's Encrypt certificate registration)
- API Token with DNS:Edit permissions
- Account ID
- Zone ID for your domain

To find these:
1. Log in to Cloudflare dashboard
2. Go to "My Profile" → "API Tokens" → "Create Token" → Use the "Edit zone DNS" template
3. For Account ID, go to the Cloudflare dashboard and check the URL while on the Account Home page: `https://dash.cloudflare.com/<Account ID>`
4. For Zone ID, go to the overview page for your domain

### 3. Run the setup script

```bash
sudo ./setup.sh yourdomain.com
```

The script will:
- Prompt for your Cloudflare credentials
- Generate a random UUID for V2Ray
- Set up the necessary configuration files
- Install Docker and Docker Compose if needed
- Obtain SSL certificates via Cloudflare DNS validation
- Start the V2Ray server
- Generate client configuration details

### 4. Configure Cloudflare (optional but recommended)

The setup script can automatically create the necessary DNS records in Cloudflare with proxying enabled. However, you can also configure them manually:

To hide your server's IP address:
1. In Cloudflare DNS settings, make sure the A record (IPv4) for your domain has the proxy enabled (orange cloud icon)
2. Set SSL/TLS encryption mode to "Full (strict)"

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
- Check the logs: `docker-compose logs v2ray` or `docker-compose logs acme`
- Run the security check script: `./secure-check.sh`
- Make sure your Cloudflare API credentials are correct
- Verify that ports are not blocked by your firewall
- Ensure your domain is properly configured in Cloudflare

To restart the service after making changes:
```bash
./restart.sh
```

To check for common security issues:
```bash
./secure-check.sh
```

## Security Considerations

- The setup uses TLS to encrypt traffic
- Cloudflare proxy adds an additional layer of security
- HTTP header camouflage makes the traffic appear like normal web browsing
- Private IP access is blocked to prevent potential security issues
- Automatic security checks help maintain server security
- Regular certificate renewal ensures TLS remains valid
- Decoy website makes the server appear as a legitimate web host
- Be careful when sharing your VMess URL as it contains your server details

## License

This project is licensed under the MIT License - see the LICENSE file for details.
