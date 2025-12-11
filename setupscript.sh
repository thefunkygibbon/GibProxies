#!/bin/bash
# GibProxy installer script
# Version: 1.1

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIB_DIR="${BASE_DIR}/gibproxy"

clear

cat << "EOF"
    ╔════════════════════════════════════════════════════════════╗
    ║      GibProxy VPN & Tor Router Installer                   ║
    ║                                                            ║
    ║        .-\"\"\"-.                                          ║
    ║       /  _  _  \                                           ║
    ║       | (.)(.) |                                           ║
    ║       \   ^^   /                                           ║
    ║        '.___.'                                             ║
    ║         /   \                                              ║
    ║        /_____\\                                            ║
    ║  Routes YouTube/Netflix or ALL via VPN, rest via Tor       ║
    ╚════════════════════════════════════════════════════════════╝
EOF

if [[ ! -d "$GIB_DIR" ]]; then
  echo "ERROR: gibproxy folder not found at: $GIB_DIR"
  echo "Create it and place docker-compose.yml and router.js inside it first."
  exit 1
fi

cd "$GIB_DIR"

# 1. VPN CONFIG
echo "VPN Provider (surfshark/mullvad/nordvpn/protonvpn/custom): "
read VPN_PROVIDER

echo "VPN Tech (openvpn/wireguard): "
read VPN_TECH

echo "VPN Country (Albania/United States/Ireland/Switzerland/custom): "
read VPN_COUNTRY

if [[ $VPN_TECH == "openvpn" ]]; then
  read -s -p "OpenVPN Username: " VPN_USER; echo
  read -s -p "OpenVPN Password: " VPN_PASS; echo
elif [[ $VPN_TECH == "wireguard" ]]; then
  read -s -p "WireGuard Private Key: " WG_KEY; echo
  read -p "WireGuard Endpoint: " WG_ENDPOINT
fi

# 2. SERVICES
echo ""
echo "Services to route via VPN:"
echo " 1) Netflix only"
echo " 2) YouTube only" 
echo " 3) Both Netflix + YouTube"
echo " 4) ALL traffic (except .onion) via VPN"
read -p "Choice (1-4): " SVC_CHOICE

case $SVC_CHOICE in
  1) SERVICES="netflix";;
  2) SERVICES="youtube";;
  3) SERVICES="netflix,youtube";;
  4) SERVICES="all";;
  *) echo "Invalid choice"; exit 1;;
esac

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
else
  update_env "WIREGUARD_PRIVATE_KEY" "$WG_KEY"
  update_env "WIREGUARD_ENDPOINT_IP" "$WG_ENDPOINT"
fi

# Ensure the compose file mounts router.js from THIS folder:
# (idempotent: replace if present, otherwise append under volumes)
if grep -q "/config/router.js" docker-compose.yml; then
  sed -i 's#.*router.js:/config/router.js:ro#      - ./router.js:/config/router.js:ro#' docker-compose.yml
else
  sed -i '/volumes:/a\      - ./router.js:/config/router.js:ro' docker-compose.yml
fi

# 5. REBUILD router.js (in gibproxy/)
> router.js.tmp

cat >> router.js.tmp << 'EOF'
const TOR_PROXY = 'socks5://tor:9050';
const VPN_PROXY = 'http://gluetun:8888';

function normalizeHost(host) {
  return (host || '').toLowerCase().replace(/:\d+$/, '');
}
EOF

# Service matchers only needed if not "all"
if [[ $SERVICES != "all" ]]; then
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
fi

cat >> router.js.tmp << 'EOF'
function getProxy(req, dst, username) {
  const host = normalizeHost(dst.originalHost || req.host || "");
EOF

if [[ $SERVICES == "all" ]]; then
  cat >> router.js.tmp << 'EOF'
  if (host.endsWith('.onion')) return TOR_PROXY;
  return VPN_PROXY;
}
EOF
else
  [[ $SERVICES == *"netflix"* ]] && echo "  if (isNetflixHost(host)) return VPN_PROXY;" >> router.js.tmp
  [[ $SERVICES == *"youtube"* ]] && echo "  if (isYouTubeHost(host)) return VPN_PROXY;" >> router.js.tmp

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
  SHOW_SERVICES="$SERVICES"
fi

cat << EOF

✅ CONFIGURATION COMPLETE! (v1.1)

📂 Config folder:
  ${GIB_DIR}

📋 Services via VPN: ${SHOW_SERVICES}
🌍 VPN Provider: ${VPN_PROVIDER} (${VPN_COUNTRY})
🔌 VPN Tech: ${VPN_TECH}

📁 Volume Mapping
docker-compose.yml (inside gibproxy) should have:
  - "./router.js:/config/router.js:ro"

This means Docker will mount:
  ${GIB_DIR}/router.js  →  /config/router.js in the dumbproxy container.

If you move the gibproxy folder elsewhere, run Docker from that new folder
or adjust the volume path accordingly.

🔄 To START services, run from inside gibproxy:
  cd "${GIB_DIR}"
  docker compose down    # (if already running)
  docker compose up -d

📋 Backups created (in gibproxy):
  - docker-compose.yml.bak
  - router.js.bak

🧪 Test commands:
  curl -x http://localhost:8080 https://www.netflix.com -I
  curl -x http://localhost:8080 https://www.youtube.com -I

EOF
