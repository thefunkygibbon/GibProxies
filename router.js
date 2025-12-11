
// Upstream proxies
const TOR_PROXY = "socks5://vpn-proxy:9150";
const VPN_PROXY = "http://vpn-proxy:8888";

// Normalize hostname helper
function normalizeHost(h) {
  if (!h) return "";
  return h.replace(/\.$/, "").toLowerCase();
}

function isTorHost(host) {
  // .onion domains to Tor
  return normalizeHost(host).endsWith(".onion");
}

function isVPNHost(host) {
  const h = normalizeHost(host);
  // Core domains to route via VPN; add/trim as needed
  return (
    h.endsWith("domain.com") ||
    h.endsWith("domain2.com") ||
    h.endsWith("reddit.com")
  // Remember the last one doesn't need the || at the end, but all the others do. 
);
}

// Called by dumbproxy to pick upstream proxy
function getProxy(req, dst, username) {
  const host = dst.originalHost || req.host || "";

  if (isTorHost(host)) {
    // Route .onion via Tor SOCKS5 proxy
    return TOR_PROXY;
  }

  if (isVPNHost(host)) {
    // Route specific domains via HTTP/HTTPS upstream VPN proxy
    return VPN_PROXY;
  }

  // Anything else goes direct
  return "";
}
