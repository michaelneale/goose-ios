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

start_tailscaled() {
  if pgrep -f "tailscaled --tun=userspace-networking" >/dev/null; then
    echo "✅ tailscaled already running."
    return
  fi
  echo "▶️ Starting tailscaled in userspace..."
  nohup tailscaled \
    --tun=userspace-networking \
    --statedir "$TS_STATE" \
    --socket "$TS_SOCK" \
    >"$LOG_FILE" 2>&1 &
  for i in {1..25}; do
    [ -S "$TS_SOCK" ] && break
    sleep 0.2
  done
}

stop_tailscaled() {
  echo "🛑 Stopping tailscaled..."
  pkill -f 'tailscaled --tun=userspace-networking' || true
}

serve_local() {
  echo "🌐 Serving localhost:$PORT over tailnet (HTTP)..."
  tailscale --socket "$TS_SOCK" serve --http=80 127.0.0.1:$PORT
}

show_info() {
  echo ""
  echo "🔍 Connection info:"
  HOST=$(tailscale --socket "$TS_SOCK" status --json 2>/dev/null | jq -r '.Self.HostName // empty')
  IPV4=$(tailscale --socket "$TS_SOCK" ip -4 2>/dev/null | head -n1)
  IPV6=$(tailscale --socket "$TS_SOCK" ip -6 2>/dev/null | head -n1)
  echo "  MagicDNS:   http://$HOST.ts.net/"
  echo "  IPv4:       http://$IPV4/"
  echo "  IPv6:       http://[$IPV6]/"
  echo ""
}

trap stop_tailscaled EXIT

start_tailscaled
tailscale --socket "$TS_SOCK" up >/dev/null
show_info
serve_local


echo "Press Ctrl+C to stop."
# Keep process alive so Serve remains active
tail -f /dev/null
