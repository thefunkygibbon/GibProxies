# Docker Smart Proxy: Tor + VPN Routing

[![Docker Compose](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)
[![Tor](https://img.shields.io/badge/Tor-SOCKS-green.svg)](https://www.torproject.org/)
[![Gluetun VPN](https://img.shields.io/badge/VPN-Gluetun-orange.svg)](https://github.com/qdm12/gluetun)Compose:
- **.onion sites** → Tor SOCKS (over VPN tunnel)
- **YouTube domains** → VPN HTTP proxy 
- **Everything else** → direct Internet

No client-side proxy switching needed. Browser points at single HTTP proxy endpoint.

## Features
- JS-based domain routing
- Tor anonymity + VPN egress in one chain
- VPN with Wireguard/OpenVPN support
- Customizable domain matching
- Works with any HTTP(S)-aware browser/app/device

## Architecture
```
Client (Browser) → dumbproxy:8080 → {
  .onion    → vpn-proxy:9150 (Tor SOCKS) → VPN → Internet
  specificdomains → vpn-proxy:8888 (HTTP proxy) → VPN → Internet  
  *        → direct from host
}
```
## Technologies used
 - Dumbproxy - https://github.com/SenseUnit/dumbproxy
 - Gluetun VPN Proxy - https://github.com/qdm12/gluetun
 - Tor Proxy - https://github.com/PeterDaveHello/tor-socks-proxy
   
## Prerequisites
- Docker & Docker Compose
- Supported Wireguard/OpenVPN provider and credentials ([As per this list](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)
- Custom Wireguard/OpenVPN if it isn't listed above [as per this list](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/custom.md))

## Quick Start

1. **Clone & prepare**
```
git clone https://github.com/thefunkygibbon/GibProxies
cd GibProxies
```

2. **Configure settings (guided)**

There are two options,  you can use the setupscript.sh
```
chmod 777 setupscript.sh
./setupscript.sh
```
This will walk you through the configuration where you simply need to enter your VPN provider name [as per this link](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers), then choose openvpn or wireguard (personally I found openvpn to be better with my vpn provider), enter credentials,  choose what you want to route via the vpn (have included youtube and netflix as options,  you can add other domains by editing the resulting router.js file, see below).

  2.5  **Configure settings (manually)**

If you wanted to do things a bit more manually then you just need to edit the docker-compose.yml and make sure that the below 
```
VPN_SERVICE_PROVIDER=name as per https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers
VPN_TYPE=openvpn/wireguard
```
If you use openvpn make sure these are filled in correctly
```
OPENVPN_USER=your_OVPN_user
OPENVPN_PASSWORD=your_OVPN_pass
```
and if you use Wireguard,  just fill these two in.
```
WIREGUARD_PRIVATE_KEY=wOE23fsdfbDwnN8/Bptgergre8T71v32f33fmFWujulwUU=  (or whatever is provided by your VPN provider)
WIREGUARD_ADDRESSES=10.60.221.3/32 (or whatever is provided by your VPN provider)
```
Note that it doesn't care if you fill all of those in, it will only use the vpn type as defined in VPN_TYPE.

Next you need to edit router.js so that it includes all of the domains you want to route via the VPN
Find the section which lists the following, and simply change the domain names, you can add extras if you wish. Just remember to add the || at the end of each line (except the last one)
```
    h.endsWith("domain.com") ||
    h.endsWith("domain2.com") ||
    h.endsWith("domain3.com")
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
