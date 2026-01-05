# Matrix Server Docker Compose

A high-performance, production-ready Matrix homeserver stack featuring:

- **[Conduit](https://conduit.rs/)** - Lightning-fast Matrix homeserver written in Rust
- **[LiveKit](https://livekit.io/)** - Real-time audio/video communication for Matrix calls
- **[Caddy](https://caddyserver.com/)** - Automatic HTTPS reverse proxy

## Features

- 🚀 **High Performance**: Conduit is one of the fastest Matrix homeservers available
- 🔒 **Automatic HTTPS**: Caddy handles Let's Encrypt certificates automatically
- 📞 **Voice/Video Calls**: Native Matrix RTC support via LiveKit
- 🐳 **Docker-based**: Easy deployment and updates
- ⚡ **HTTP/3 Support**: Modern protocol support for better performance
- 🔗 **Federation Ready**: Connect with the wider Matrix network

## Prerequisites

- Docker and Docker Compose v2+
- A domain name with DNS configured
- Ports 80, 443, 8448 (TCP) and 7882 (UDP) open on your firewall

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/meshya/matrix-server-docker-compose.git
cd matrix-server-docker-compose

# Copy and edit the environment file
cp .env.example .env
```

### 2. Configure Your Domain

Edit the following files and replace `example.com` with your domain:

#### `conduit.toml`
```toml
server_name = "matrix.yourdomain.com"
```

#### `Caddyfile`
Replace all instances of:
- `matrix.example.com` → `matrix.yourdomain.com`
- `livekit.example.com` → `livekit.yourdomain.com`
- `admin@example.com` → your email

#### `livekit.yaml`
```yaml
turn:
  domain: livekit.yourdomain.com
```

### 3. Generate LiveKit API Keys

```bash
# Generate API key
openssl rand -hex 16

# Generate API secret
openssl rand -hex 32
```

Update `livekit.yaml` with your generated keys:
```yaml
keys:
  YOUR_API_KEY: YOUR_API_SECRET
```

### 4. DNS Configuration

Create the following DNS records pointing to your server:

| Type | Name | Value |
|------|------|-------|
| A | matrix.yourdomain.com | Your Server IP |
| A | livekit.yourdomain.com | Your Server IP |

For federation, also add:
| Type | Name | Value |
|------|------|-------|
| SRV | _matrix._tcp.yourdomain.com | 10 0 443 matrix.yourdomain.com |

### 5. Start the Server

```bash
docker compose up -d
```

### 6. Create Admin User

```bash
# Access the Conduit container
docker compose exec conduit /bin/sh

# Create an admin user (inside the container)
# The server will guide you through user creation via the admin API
```

Or use the Matrix API:
```bash
curl -X POST "https://matrix.yourdomain.com/_matrix/client/v3/register" \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "your-secure-password", "auth": {"type": "m.login.dummy"}}'
```

## Configuration

### Conduit (Matrix Homeserver)

Main configuration file: `conduit.toml`

Key settings:
- `server_name`: Your Matrix domain (cannot be changed after setup!)
- `allow_registration`: Enable/disable public registration
- `allow_federation`: Enable/disable federation with other servers
- `rocksdb_cache_capacity_mb`: Database cache size (adjust based on RAM)

### LiveKit (Voice/Video)

Configuration file: `livekit.yaml`

Key settings:
- `keys`: API authentication keys
- `turn.domain`: TURN server domain for NAT traversal
- `room.max_participants`: Maximum users per call

### Caddy (Reverse Proxy)

Configuration file: `Caddyfile`

Features:
- Automatic HTTPS via Let's Encrypt
- HTTP/3 support
- Proper WebSocket handling for Matrix sync

## Ports

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 80 | TCP | Caddy | HTTP (redirects to HTTPS) |
| 443 | TCP/UDP | Caddy | HTTPS / HTTP/3 |
| 8448 | TCP | Caddy | Matrix Federation |
| 7882 | UDP | LiveKit | WebRTC Media |
| 5349 | TCP | LiveKit | TURN/TLS |

## Maintenance

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f conduit
docker compose logs -f livekit
docker compose logs -f caddy
```

### Update Images

```bash
docker compose pull
docker compose up -d
```

### Backup

```bash
# Stop services
docker compose down

# Backup data volumes
docker run --rm -v matrix-server-docker-compose_conduit_data:/data -v $(pwd):/backup alpine tar czf /backup/conduit-backup.tar.gz /data

# Restart services
docker compose up -d
```

### Health Check

```bash
# Check Matrix server
curl https://matrix.yourdomain.com/_matrix/client/versions

# Check federation
curl https://matrix.yourdomain.com:8448/_matrix/federation/v1/version
```

## Troubleshooting

### Certificates not working
- Ensure ports 80 and 443 are open
- Check Caddy logs: `docker compose logs caddy`
- Verify DNS is pointing to your server

### Federation issues
- Check port 8448 is open
- Verify SRV records: `dig _matrix._tcp.yourdomain.com SRV`
- Test with [Matrix Federation Tester](https://federationtester.matrix.org/)

### Call quality issues
- Ensure UDP port 7882 is open
- Check LiveKit logs: `docker compose logs livekit`
- Verify TURN is working for clients behind strict NAT

## Security Recommendations

1. **Firewall**: Only expose necessary ports
2. **Updates**: Regularly update Docker images
3. **Backups**: Implement automated backup strategy
4. **Monitoring**: Set up health monitoring and alerting
5. **Rate Limiting**: Consider adding rate limiting in Caddy

## Matrix Clients

Connect using any Matrix client:
- [Element](https://element.io/) (Web, Desktop, Mobile)
- [FluffyChat](https://fluffychat.im/) (Mobile)
- [Nheko](https://nheko.im/) (Desktop)
- [Cinny](https://cinny.in/) (Web)

Server address: `https://matrix.yourdomain.com`

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
