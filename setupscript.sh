#!/bin/bash
# GibProxy installer script
# Version: 1.5 (multi-select services)

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIB_DIR="${BASE_DIR}/gibproxy"

# Improved IP detection: Get IP from default route interface
get_host_ip() {
  DEFAULT_IFACE=$(ip route show default | head -n1 | awk '{print $5}' 2>/dev/null)
  if [[ -n "$DEFAULT_IFACE" && "$DEFAULT_IFACE" != "lo" ]]; then
    IP=$(ip -4 addr show dev "$DEFAULT_IFACE" | grep "inet " | awk '{print $2}' | cut -d'/' -f1 | head -n1 2>/dev/null)
    if [[ -n "$IP" && "$IP" != "127.0.0.1" ]]; then
      echo "$IP"
      return 0
    fi
  fi
  # Fallback: first non-loopback IP
  ip -4 addr show | grep -v "lo:" | grep "inet " | head -n1 | awk '{print $2}' | cut -d'/' -f1 2>/dev/null || echo "127.0.0.1"
}

DOCKER_HOST_IP=$(get_host_ip)
clear

cat << "EOF"
    ╔════════════════════════════════════════════════════════╗
    ║          GibProxy VPN & Tor Router Installer           ║
    ║                  __                                    ║                                     
    ║             w  c(..)o   (                              ║
    ║              \__(-)    __)                             ║
    ║                  /\   (                                ║
    ║                 /(_)___)                               ║
    ║                 w /|                                   ║
    ║                  | \                                   ║
    ║                  m  m                                  ║
    ║  Routes YouTube/Netflix/Adult or ALL via VPN, rest Tor ║
    ╚════════════════════════════════════════════════════════╝
    
EOF

if [[ ! -d "$GIB_DIR" ]]; then
  echo "ERROR: gibproxy folder not found at: $GIB_DIR"
  echo "Create it and place docker-compose.yml and router.js inside it first."
  exit 1
fi

cd "$GIB_DIR"

# 1. VPN CONFIG
while true; do
  echo "VPN Provider (surfshark/mullvad/nordvpn/protonvpn/custom): "
  read VPN_PROVIDER
  if [[ -n "$VPN_PROVIDER" ]]; then
    break
  fi
  echo "Please enter a VPN provider (e.g. surfshark, mullvad, etc.)."
done

while true; do
  echo "VPN Tech (openvpn/wireguard): "
  read VPN_TECH
  if [[ -n "$VPN_TECH" ]]; then
    break
  fi
  echo "Please enter a VPN tech (openvpn or wireguard)."
done

while true; do
  echo "VPN Country (Albania/United States/Ireland/Switzerland/custom): "
  read VPN_COUNTRY
  if [[ -n "$VPN_COUNTRY" ]]; then
    break
  fi
  echo "Please enter a VPN country (e.g. United States, Ireland, etc.)."
done

OPENVPN_ENDPOINT_IP=""
WIREGUARD_ENDPOINT_IP=""

if [[ $VPN_TECH == "openvpn" ]]; then
  while true; do
    read -p "OpenVPN Username: " VPN_USER
    if [[ -n "$VPN_USER" ]]; then
      break
    fi
    echo "Username cannot be empty. Please enter a valid username."
  done
  while true; do
    read -p "OpenVPN Password: " VPN_PASS
    if [[ -n "$VPN_PASS" ]]; then
      break
    fi
    echo "Password cannot be empty. Please enter a valid password."
  done
elif [[ $VPN_TECH == "wireguard" ]]; then
  while true; do
    read -p "WireGuard Private Key: " WG_KEY
    if [[ -n "$WG_KEY" ]]; then
      break
    fi
    echo "Private key cannot be empty. Please enter a valid private key."
  done
  while true; do
    echo "WireGuard Addresses example: 10.64.0.2/32"
    read -p "WireGuard Addresses: " WG_ADDR
    if [[ -n "$WG_ADDR" ]]; then
      break
    fi
    echo "Addresses cannot be empty. Please enter a valid WireGuard address."
  done
fi

# Optional endpoint IP
echo ""
while true; do
  read -p "Do you want to specify a VPN endpoint/server IP address? (y/N): " EP_CHOICE
  if [[ -z "$EP_CHOICE" ]]; then
    EP_CHOICE="n"
  fi
  case "$EP_CHOICE" in
    [Yy]*|[Nn]*)
      break
      ;;
    *)
      echo "Please answer y or n."
      ;;
  esac
done

if [[ "$EP_CHOICE" =~ ^[Yy]$ ]]; then
  if [[ $VPN_TECH == "openvpn" ]]; then
    while true; do
      read -p "OpenVPN Endpoint IP: " OPENVPN_ENDPOINT_IP
      if [[ -n "$OPENVPN_ENDPOINT_IP" ]]; then
        break
      fi
      echo "Endpoint IP cannot be empty. Please enter a valid IP address."
    done
  else
    while true; do
      read -p "Wireguard Endpoint IP: " WIREGUARD_ENDPOINT_IP
      if [[ -n "$WIREGUARD_ENDPOINT_IP" ]]; then
        break
      fi
      echo "Endpoint IP cannot be empty. Please enter a valid IP address."
    done
  fi
fi

# 2. SERVICES - Multi-select
echo ""
echo "Services to route via VPN (space-separated numbers, e.g. '1 3' for YouTube+Adult):"
echo " 1) YouTube"
echo " 2) Netflix"
echo " 3) Adult sites (pornhub/xvideos/onlyfans/etc)"
echo " 4) All of the above (1+2+3)"
echo " 5) ALL traffic (except .onion)"

while true; do
  read -p "Choice: " SVC_CHOICE
  case $SVC_CHOICE in
    4)
      SERVICES="youtube,netflix,adult"; break ;;
    5)
      SERVICES="all"; break ;;
    *)
      # Parse multiple selections
      SELECTED=""
      HAS_YOUTUBE=false
      HAS_NETFLIX=false
      HAS_ADULT=false
      
      for num in $SVC_CHOICE; do
        case $num in
          1) HAS_YOUTUBE=true ;;
          2) HAS_NETFLIX=true ;;
          3) HAS_ADULT=true ;;
          *) echo "Invalid number '$num'. Use 1-5 only."; SELECTED=""; break 2 ;;
        esac
      done
      
      if [[ -n "$SELECTED" || ( -n "${HAS_YOUTUBE:-}" || -n "${HAS_NETFLIX:-}" || -n "${HAS_ADULT:-}" ) ]]; then
        if [[ $HAS_YOUTUBE == true ]]; then SELECTED+="${SELECTED+,}youtube"; fi
        if [[ $HAS_NETFLIX == true ]]; then SELECTED+="${SELECTED+,}netflix"; fi
        if [[ $HAS_ADULT == true ]]; then SELECTED+="${SELECTED+,}adult"; fi
        SERVICES="$SELECTED"
        break
      fi
      echo "Please enter valid numbers (1-5, space separated, or 4/5)."
      ;;
  esac
done

# 3. BACKUP (inside gibproxy)
cp -n docker-compose.yml docker-compose.yml.bak 2>/dev/null || true
cp -n router.js router.js.bak 2>/dev/null || true

# 4. UPDATE docker-compose.yml (in gibproxy/)
update_env() {
  local key="$1" value="$2"
  if grep -q "$key=" docker-compose.yml; then
    sed -i "/$key=/c\      - $key=$value" docker-compose.yml
  else
    sed -i '/environment:/a\      - '"$key=$value" docker-compose.yml
  fi
}

update_env "VPN_SERVICE_PROVIDER" "$VPN_PROVIDER"
update_env "VPN_TYPE" "$VPN_TECH"
update_env "SERVER_COUNTRIES" "$VPN_COUNTRY"

if [[ $VPN_TECH == "openvpn" ]]; then
  update_env "OPENVPN_USER" "$VPN_USER"
  update_env "OPENVPN_PASSWORD" "$VPN_PASS"
  if [[ -n "$OPENVPN_ENDPOINT_IP" ]]; then
    update_env "OPENVPN_ENDPOINT_IP" "$OPENVPN_ENDPOINT_IP"
  fi
else
  update_env "WIREGUARD_PRIVATE_KEY" "$WG_KEY"
  update_env "WIREGUARD_ADDRESSES" "$WG_ADDR"
  if [[ -n "$WIREGUARD_ENDPOINT_IP" ]]; then
    update_env "WIREGUARD_ENDPOINT_IP" "$WIREGUARD_ENDPOINT_IP"
  fi
fi

# Ensure the compose file mounts router.js from THIS folder:
if grep -q "/config/router.js" docker-compose.yml; then
  sed -i 's#.*router.js:/config/router.js:ro#      - ./router.js:/config/router.js:ro#' docker-compose.yml
else
  sed -i '/volumes:/a\      - ./router.js:/config/router.js:ro' docker-compose.yml
fi

# 5. REBUILD router.js (in gibproxy/)
> router.js.tmp

# Updated proxies: both via vpn-proxy, Tor on 9150
cat >> router.js.tmp << 'EOF'
const TOR_PROXY = 'socks5://vpn-proxy:9150';
const VPN_PROXY = 'http://vpn-proxy:8888';

function normalizeHost(host) {
  return (host || '').toLowerCase().replace(/:\d+$/, '');
}
EOF

# Service matchers only needed if not "all"
if [[ $SERVICES != "all" ]]; then
  if [[ $SERVICES == *"youtube"* ]]; then
    cat >> router.js.tmp << 'EOF'
function isYouTubeHost(host) {
  const h = normalizeHost(host);
  const YOUTUBE_DOMAINS = `youtube.com
youtube-nocookie.com
ytimg.com
googlevideo.com
youtube.googleapis.com
youtubei.googleapis.com
ytstatic.com
ggpht.com
youtubeeducation.com
youtu.be`.split('\n').filter(Boolean);
  return YOUTUBE_DOMAINS.some(d => h.endsWith(d.trim()));
}
EOF
  fi

  if [[ $SERVICES == *"netflix"* ]]; then
    cat >> router.js.tmp << 'EOF'
function isNetflixHost(host) {
  const h = normalizeHost(host);
  const NETFLIX_DOMAINS = `netflix.com
netflix.net
nflxext.com
nflximg.com
nflximg.net
nflxso.net
nflxvideo.net
netflixstudios.com
netflixpartners.com`.split('\n').filter(Boolean);
  return NETFLIX_DOMAINS.some(d => h.endsWith(d.trim()));
}
EOF
  fi

  if [[ $SERVICES == *"adult"* ]]; then
    cat >> router.js.tmp << 'EOF'
function isAdultHost(host) {
  const h = normalizeHost(host);
  const ADULT_DOMAINS = `pornhub.com
xvideos.com
xhamster.com
onlyfans.com
redtube.com
reddit.com
redgifs.com
imgur.com`.split('\n').filter(Boolean);
  return ADULT_DOMAINS.some(d => h.endsWith(d.trim()));
}
EOF
  fi
fi

# Always add ifconfig.io matcher – should go via VPN regardless of mode
cat >> router.js.tmp << 'EOF'
function isWhatsMyIpHost(host) {
  const h = normalizeHost(host);
  const WMI_DOMAINS = `ifconfig.io`.split('\n').filter(Boolean);
  return WMI_DOMAINS.some(d => h.endsWith(d.trim()));
}
EOF

cat >> router.js.tmp << 'EOF'
function getProxy(req, dst, username) {
  const host = normalizeHost(dst.originalHost || req.host || "");
EOF

if [[ $SERVICES == "all" ]]; then
  # All traffic except .onion via VPN
  cat >> router.js.tmp << 'EOF'
  if (host.endsWith('.onion')) return TOR_PROXY;
  if (isWhatsMyIpHost(host)) return VPN_PROXY;
  return VPN_PROXY;
}
EOF
else
  [[ $SERVICES == *"youtube"* ]] && echo "  if (isYouTubeHost(host)) return VPN_PROXY;" >> router.js.tmp
  [[ $SERVICES == *"netflix"* ]] && echo "  if (isNetflixHost(host)) return VPN_PROXY;" >> router.js.tmp
  [[ $SERVICES == *"adult"* ]] && echo "  if (isAdultHost(host)) return VPN_PROXY;" >> router.js.tmp
  echo "  if (isWhatsMyIpHost(host)) return VPN_PROXY;" >> router.js.tmp

  cat >> router.js.tmp << 'EOF'
  if (host.endsWith('.onion')) return TOR_PROXY;
  return '';
}
EOF
fi

mv router.js.tmp router.js

# 6. FINAL INSTRUCTIONS
clear

if [[ $SERVICES == "all" ]]; then
  SHOW_SERVICES="ALL traffic (except .onion)"
else
  SHOW_SERVICES="$SERVICES + ifconfig.io"
fi

cat << EOF
CONFIGURATION COMPLETE! (v1.5)
===============================

Config folder: ${GIB_DIR}

VPN: ${VPN_PROVIDER} (${VPN_COUNTRY}) via ${VPN_TECH}
Services: ${SHOW_SERVICES}
Proxy IP: ${DOCKER_HOST_IP}:8080

Volume: ${GIB_DIR}/router.js -> /config/router.js (dumbproxy)

START SERVICES (from gibproxy/):
- cd ${GIB_DIR}
- docker compose down
- docker compose up -d

BROWSER SETUP:
Configure browser to use HTTP proxy:
Host: ${DOCKER_HOST_IP}
Port: 8080
Type: HTTP proxy (not SOCKS)

Backups: docker-compose.yml.bak, router.js.bak

TEST:
curl -x http://${DOCKER_HOST_IP}:8080 https://ifconfig.me      # Host ISP IP
curl -x http://${DOCKER_HOST_IP}:8080 https://ifconfig.io      # VPN IP  
curl -x http://${DOCKER_HOST_IP}:8080 https://www.bbcnewsd73hkzno2ini43t4gblxvycyac5aw4gnv7t2rccijh7745uqd.onion/  # Tor

EOF
