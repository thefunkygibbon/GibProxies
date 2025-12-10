# Docker Smart Proxy: Tor + VPN Routing

[![Docker Compose](https://img.shields.io/badge/Docker-Compose![Tor](https://img.shields.io/badge/Tor-SOCKS-green![Gluetun VPN](https://img.shields.io/badge/VPN-Gluetun-orangeSelective traffic routing via Docker Compose:
- **.onion sites** → Tor SOCKS (over VPN tunnel)
- **YouTube domains** → VPN HTTP proxy 
- **Everything else** → direct Internet

No client-side proxy switching needed. Browser points at single HTTP proxy endpoint.

## Features
- JS-based domain routing (dumbproxy)
- Tor anonymity + VPN egress in one chain
- Gluetun VPN with Surfshark/OpenVPN support
- Customizable domain matching
- Works with any HTTP(S)-aware browser/app

## Architecture
```
Client (Browser) → dumbproxy:8080 → {
  .onion    → vpn-proxy:9150 (Tor SOCKS) → VPN tunnel → Internet
  youtube.* → vpn-proxy:8888 (HTTP proxy) → VPN → Internet  
  *        → direct from host
}
```

## Prerequisites
- Docker & Docker Compose
- Existing Docker bridge network `gibbridge` (or adapt `networks:`)
- Surfshark/OpenVPN credentials

## Quick Start

1. **Clone & prepare**
```
git clone https://github.com/YOURUSERNAME/docker-smart-proxy-tor-vpn
cd docker-smart-proxy-tor-vpn
cp .env.example .env
```

2. **Edit `.env`**
```
VPN_SERVICE_PROVIDER=surfshark
VPN_TYPE=openvpn
OPENVPN_USER=your_surfshark_user
OPENVPN_PASSWORD=your_surfshark_pass
SERVER_COUNTRIES=Albania
```

3. **Deploy**
```
docker compose up -d
```

4. **Configure browser**
```
HTTP Proxy: <host-ip>:8080
HTTPS Proxy: <host-ip>:8080
```

## Domain Routing Logic

**router.js** handles all decisions:

```
// .onion → Tor SOCKS over VPN
if (host.endsWith('.onion')) return 'socks5://vpn-proxy:9150';

// YouTube → VPN HTTP proxy  
if (isYouTubeHost(host)) return 'http://vpn-proxy:8888';

// Everything else → direct
return '';
```

**YouTube domains covered:**
- `*.youtube.com`
- `youtube-nocookie.com`
- `youtu.be`
- `ytimg.com` (thumbnails/CDN)
- `googlevideo.com` (video streaming)

## docker-compose.yml

```
version: "3.8"

services:
  vpn-proxy:
    image: qmcgaw/gluetun
    container_name: vpn-proxy
    networks:
      - gibbridge
    env_file: .env
    environment:
      - HTTPPROXY=on
      - HTTPPROXY_LISTENING_ADDRESS=:8888
    restart: unless-stopped

  tor:
    image: peterdavehello/tor-socks-proxy
    container_name: tor
    network_mode: "service:vpn-proxy"
    restart: unless-stopped
    depends_on:
      - vpn-proxy

  dumbproxy:
    image: ghcr.io/senseunit/dumbproxy:latest-alpine
    container_name: dumbproxy
    command:
      - -bind-address=:8080
      - -js-proxy-router=/config/router.js
    ports:
      - "8080:8080"
    volumes:
      - ./router.js:/config/router.js:ro
    networks:
      - gibbridge
    depends_on:
      - vpn-proxy
      - tor
    restart: unless-stopped

networks:
  gibbridge:
    external: true
```

## Verification

1. **Check VPN routing**
```
docker exec vpn-proxy sh -c "curl https://ifconfig.io"
# Should show VPN IP, not ISP IP
```

2. **Test Tor chain**
Browser → `http://check.torproject.org` via proxy should confirm "You are using Tor"

3. **Test selective routing**
```
curl -x http://localhost:8080 https://ifconfig.io/country     # VPN IP  
curl -x http://localhost:8080 http://facebookcorewwwi.onion/  # Tor exit
curl -x http://localhost:8080 https://example.com            # Host ISP IP
```

## Troubleshooting

**"lookup tor/vpn-proxy: server misbehaving"**
- All services must be on same Docker network (`gibbridge`)

**Tor won't bootstrap**
```
docker logs tor
# Look for "Bootstrapped 100% (done)"
```

**".onion connection refused"**
```
docker exec vpn-proxy sh -c "ss -tlnp | grep 9150"
# Tor SOCKS must be listening on vpn-proxy:9150
```

## Customization

Edit `./router.js` to add routes:
```
function isNetflixHost(host) {
  return host.includes('netflix.com');
}
if (isNetflixHost(host)) return 'http://vpn-proxy:8888';
```

## License
MIT

## Credits
- [dumbproxy](https://github.com/SenseUnit/dumbproxy) - JS routing proxy
- [Gluetun](https://github.com/qdm12/gluetun) - VPN client
- [Tor SOCKS Proxy](https://hub.docker.com/r/peterdavehello/tor-socks-proxy)
```
