# GibProxies - Docker Smart Proxy: VPN + Tor Routing

[![Docker Compose](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)
[![Tor](https://img.shields.io/badge/Tor-SOCKS-green.svg)](https://www.torproject.org/)
[![Gluetun VPN](https://img.shields.io/badge/VPN-Gluetun-orange.svg)](https://github.com/qdm12/gluetun)

- **YouTube/Netflix/UK-OSA/Custom domains** → VPN HTTP proxy +
- **.onion sites** → Tor SOCKS (over VPN tunnel)
- **Everything else** → direct Internet

No client-side proxy switching needed. Browser points at single HTTP proxy endpoint.

## Features
- JS-based domain routing
- Tor anonymity + VPN egress in one chain
- Split tunnel for browsing the rest of the internet from your normal internet
- VPN with Wireguard/OpenVPN support
- Customizable domain matching
- Works with any HTTP(S)-aware browser/app/device

## Use cases 
- Netflix + YouTube access via other countries for streaming devices to bypass country restrictions or adverts.
- Seemless and secure access to the Darkweb/Tor (recommend using incognito mode still)
- Transparently bypass age verification requirements on certain sites (OSA)
  
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
This will walk you through the configuration where you simply need to enter your VPN provider name [as per this link](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers), then choose openvpn or wireguard, enter credentials,  choose what you want to route via the vpn (have included youtube and netflix as options,  you can add other domains by editing the resulting router.js file, see below).

2.5.  **Configure settings (manually)**

If you wanted to do things a bit more manually then you just need to edit the docker-compose.yml and make sure that the below 
```
VPN_SERVICE_PROVIDER=name (as per link above)
VPN_TYPE=openvpn or wireguard
```
If you use openvpn make sure these are filled in correctly
```
OPENVPN_USER=your_OVPN_user
OPENVPN_PASSWORD=your_OVPN_pass
```
and if you use Wireguard,  just fill these two in.
```
WIREGUARD_PRIVATE_KEY=wOEjufsdfbDwnN8/Bpt7133WujulwUU=  (provided by your VPN provider)
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

4. **Configure browser/devices**

**Web Browsers**

Chrome: Settings > System > Open proxy settings > Manual proxy: HTTP/HTTPS

Firefox: Settings > General > Network Settings > Manual proxy: HTTP/HTTPS

Edge: Settings > System and performance > Open proxy settings > Manual proxy: HTTP/HTTPS

**Mobile Devices**

Android: Settings > Connections > Connected Wifi network Settings Cog > View more > Proxy > Manual

iOS: Settings > Wi-Fi > [network] > Configure Proxy > Manual

**Streaming Devices**

NVIDIA Shield/Android TV: Settings > Network > Advanced > Proxy > Manual, Host ${DOCKER_HOST_IP}, Port 8080 (use apps like Proxy Manager if unavailable).

Apple TV: Settings > Network > [network] > Configure Proxy > Manual, Server ${DOCKER_HOST_IP}, Port 8080.


## Verification

1. **Check normal ISP IP address**
Browse to https://ifconfig.me - Should show ISP IP

2. **Check VPN routing**
Browse to https://ifconfig.io - Should show VPN IP, not ISP IP

3. **Test Tor chain**
Browser → https://www.bbcnewsd73hkzno2ini43t4gblxvycyac5aw4gnv7t2rccijh7745uqd.onion via proxy should show the BBC's Onion website

4. **Test via CLI**
```
curl -x http://localhost:8080 https://ifconfig.me/     # Host ISP IP
curl -x http://localhost:8080 https://ifconfig.io/     # VPN IP  
curl -x http://localhost:8080 https://www.bbcnewsd73hkzno2ini43t4gblxvycyac5aw4gnv7t2rccijh7745uqd.onion/  # Tor exit
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
