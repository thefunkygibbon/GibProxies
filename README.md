# Docker Smart Proxy: Tor + VPN Routing

[![Docker Compose](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)
[![Tor](https://img.shields.io/badge/Tor-SOCKS-green.svg)](https://www.torproject.org/)
[![Gluetun VPN](https://img.shields.io/badge/VPN-Gluetun-orange.svg)](https://github.com/qdm12/gluetun)

Selective traffic routing via Docker Compose:

- **.onion sites** → Tor SOCKS (over VPN tunnel)  
- **YouTube domains** → VPN HTTP proxy  
- **Everything else** → direct Internet

Your browser/app uses a single HTTP proxy endpoint; the routing decisions happen inside the stack.

## Features

- JS-based domain routing using `dumbproxy`
- Tor anonymity with VPN egress in one chain
- Gluetun VPN with Surfshark/OpenVPN support
- Customizable per-domain routing (YouTube, etc.)
- No client-side proxy switching once configured

## Architecture

Client (Browser) → dumbproxy:8080 → {
  .onion    → vpn-proxy:9150 (Tor SOCKS) → VPN tunnel → Internet
  youtube.* → vpn-proxy:8888 (HTTP proxy) → VPN tunnel → Internet
  *         → direct from host
}

Where:
- `vpn-proxy` = Gluetun container (VPN + HTTP proxy)
- `tor` = Tor SOCKS proxy container sharing `vpn-proxy` network namespace
- `dumbproxy` = JS-routable HTTP proxy

## Prerequisites

- Docker and Docker Compose installed
