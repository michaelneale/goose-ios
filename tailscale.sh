#!/bin/bash
set -euo pipefail

# Usage: ./run-tailscale.sh 8000
PORT="${1:-}"
if [[ -z "$PORT" ]]; then
  echo "Usage: $0 <local-port>"
  exit 1
fi

TS_STATE="$HOME/.local/share/tailscale"
TS_SOCK="$HOME/.cache/tailscaled.sock"
LOG_FILE="/tmp/tailscaled.log"

mkdir -p "$TS_STATE" "$(dirname "$TS_SOCK")"

echo "▶️ Checking userspace tailscaled..."
if ! pgrep -f "tailscaled --tun=userspace-networking" >/dev/null; then
  echo "▶️ Starting userspace tailscaled..."
  nohup tailscaled \
    --tun=userspace-networking \
    --statedir "$TS_STATE" \
    --socket "$TS_SOCK" \
    >"$LOG_FILE" 2>&1 &
else
  echo "✅ tailscaled already running."
fi

# Wait for LocalAPI
for i in {1..50}; do
  if curl -sf --unix-socket "$TS_SOCK" \
      http://local-tailscaled.sock/localapi/v0/status >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

echo "🔐 Bringing up Tailscale..."
# Monitor tailscale output in real-time and open auth URL if needed
tailscale --socket "$TS_SOCK" up 2>&1 | {
  AUTH_OPENED=false
  while read line; do
    echo "$line"
    if [[ "$AUTH_OPENED" == false ]] && echo "$line" | grep -q "https://login.tailscale.com/"; then
      URL=$(echo "$line" | grep -o "https://login.tailscale.com/[^\s]*")
      echo "🌐 Opening authentication URL in browser..."
      open "$URL"
      AUTH_OPENED=true
    fi
  done
} || true


HOST=$(tailscale --socket $TS_SOCK status --json | jq -r '.Self.DNSName' | sed 's/\.$//')
V4=$(tailscale --socket "$TS_SOCK" ip -4 2>/dev/null | head -n1)
V6=$(tailscale --socket "$TS_SOCK" ip -6 2>/dev/null | head -n1)

echo ""
echo "🔎 Connection info:"
echo "  MagicDNS : http://$HOST/"
[[ -n "$V4" ]] && echo "  IPv4     : http://$V4/"
[[ -n "$V6" ]] && echo "  IPv6     : http://[$V6]/"
echo "Press Ctrl+C to exit."


echo "🌐 Ensuring Serve mapping on port 80 → localhost:$PORT ..."
tailscale --socket "$TS_SOCK" serve reset >/dev/null 2>&1 || true
tailscale --socket "$TS_SOCK" serve --tcp=80 127.0.0.1:$PORT >/dev/null

trap 'echo -e "\n🛑 Stopping Serve (daemon left running)"; tailscale --socket "$TS_SOCK" serve reset >/dev/null 2>&1 || true; exit 0' INT

while sleep 1; do :; done
