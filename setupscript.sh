#!/bin/bash
# dumbproxy-installer.sh - FIXED COUNTRY VAR
# v1.1  @thefunkygibbon

set -euo pipefail

clear

cat << "EOF"
    ╔══════════════════════════════════════════════════════╗
    ║         Gib Proxy VPN & Tor Router Installer         ║
    ╚══════════════════════════════════════════════════════╝
EOF

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
read -p "Choice (1-3): " SVC_CHOICE
case $SVC_CHOICE in 1) SERVICES="netflix";; 2) SERVICES="youtube";; 3) SERVICES="netflix,youtube";; *) exit 1;; esac

# 3. BACKUP
cp -n docker-compose.yml docker-compose.yml.bak
cp -n router.js router.js.bak

# 4. UPDATE docker-compose.yml
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

# 5. REBUILD router.js (CURRENT DIRECTORY MOUNT)
> router.js.tmp

cat >> router.js.tmp << 'EOF'
const TOR_PROXY = 'socks5://tor:9050';
const VPN_PROXY = 'http://gluetun:8888';

function normalizeHost(host) {
  return (host || '').toLowerCase().replace(/:\d+$/, '');
}
EOF

# Service matchers
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

cat >> router.js.tmp << 'EOF'
function getProxy(req, dst, username) {
  const host = normalizeHost(dst.originalHost || req.host || "");
EOF

[[ $SERVICES == *"netflix"* ]] && echo "  if (isNetflixHost(host)) return VPN_PROXY;" >> router.js.tmp
[[ $SERVICES == *"youtube"* ]] && echo "  if (isYouTubeHost(host)) return VPN_PROXY;" >> router.js.tmp

cat >> router.js.tmp << 'EOF'
  if (host.endsWith('.onion')) return TOR_PROXY;
  return '';
}
EOF

mv router.js.tmp router.js

# 6. FINAL INSTRUCTIONS
clear
cat << EOF

✅ CONFIGURATION COMPLETE!

📋 Services via VPN: $SERVICES
🌍 VPN Provider: $VPN_PROVIDER ($VPN_COUNTRY)
🔌 VPN Tech: $VPN_TECH

📁 IMPORTANT: Volume Mount
The script configured docker-compose.yml to mount:
  - "./router.js:/config/router.js:ro"

This uses the CURRENT DIRECTORY (where you ran the script).
router.js will be available to dumbproxy from this folder.

🔄 To START services, run:
  docker compose down    # (if already running)
  docker compose up -d

📋 Backups created:
  - docker-compose.yml.bak
  - router.js.bak

🧪 Test commands:
  curl -x http://localhost:8080 https://www.netflix.com -I
  curl -x http://localhost:8080 https://www.youtube.com -I

EOF
