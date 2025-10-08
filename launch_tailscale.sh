#!/bin/bash
set -e

# Configuration
PORT=62996
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Generate a random secret (32 character alphanumeric)
SECRET=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-32)

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                   Goose Tailscale Remote Access                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if goosed is available in PATH
if ! command -v goosed &> /dev/null; then
    echo -e "${RED}Error: goosed not found in PATH${NC}"
    echo -e "${YELLOW}Please add goose/target/release to your PATH${NC}"
    echo -e "${YELLOW}Example: export PATH=\$PATH:${SCRIPT_DIR}/../goose/target/release${NC}"
    exit 1
fi

# Check if qrencode is available for QR code generation
if ! command -v qrencode &> /dev/null; then
    echo -e "${RED}Error: qrencode is not installed${NC}"
    echo -e "${YELLOW}Install it with: brew install qrencode${NC}"
    exit 1
fi

# Check if tailscale is available
if ! command -v tailscale &> /dev/null; then
    echo -e "${RED}Error: tailscale is not installed${NC}"
    echo -e "${YELLOW}Install it with: brew install tailscale${NC}"
    exit 1
fi

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Shutting down...${NC}"
    if [ ! -z "$GOOSED_PID" ]; then
        echo "Stopping goosed (PID: $GOOSED_PID)"
        kill $GOOSED_PID 2>/dev/null || true
    fi
    if [ ! -z "$TAILSCALE_SERVE_PID" ]; then
        echo "Stopping Tailscale serve (PID: $TAILSCALE_SERVE_PID)"
        kill $TAILSCALE_SERVE_PID 2>/dev/null || true
    fi
    # Reset tailscale serve
    tailscale serve reset >/dev/null 2>&1 || true
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Start goosed in the background
echo -e "${GREEN}Starting goosed on port ${PORT}...${NC}"
export GOOSE_PORT=$PORT
export GOOSE_SERVER__SECRET_KEY="$SECRET"
goosed agent > /dev/null 2>&1 &
GOOSED_PID=$!

# Wait for goosed to be ready
echo "Waiting for goosed to start..."
for i in {1..30}; do
    if curl -s "http://localhost:${PORT}/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Goosed is running (PID: $GOOSED_PID)${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: goosed failed to start${NC}"
        exit 1
    fi
    sleep 0.5
done

# Setup Tailscale (similar to tailscale.sh but without the infinite loop)
TS_STATE="$HOME/.local/share/tailscale"
TS_SOCK="$HOME/.cache/tailscaled.sock"
LOG_FILE="/tmp/tailscaled.log"

mkdir -p "$TS_STATE" "$(dirname "$TS_SOCK")"

echo -e "${GREEN}Setting up Tailscale...${NC}"

# Start tailscaled if not running
if ! pgrep -f "tailscaled --tun=userspace-networking" >/dev/null; then
    echo "▶️ Starting userspace tailscaled..."
    nohup tailscaled \
        --tun=userspace-networking \
        --statedir "$TS_STATE" \
        --socket "$TS_SOCK" \
        >"$LOG_FILE" 2>&1 &

    # Wait for tailscaled to start
    for i in {1..30}; do
        if pgrep -f "tailscaled --tun=userspace-networking" >/dev/null; then
            echo -e "${GREEN}✓ tailscaled started${NC}"
            break
        fi
        sleep 0.5
    done
else
    echo -e "${GREEN}✓ tailscaled already running${NC}"
fi

# Wait for LocalAPI
for i in {1..50}; do
    if curl -sf --unix-socket "$TS_SOCK" \
        http://local-tailscaled.sock/localapi/v0/status >/dev/null 2>&1; then
        break
    fi
    sleep 0.2
done

# Bring up Tailscale and handle authentication if needed
echo "🔐 Bringing up Tailscale..."
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

# Get Tailscale URLs
echo -e "${GREEN}Getting Tailscale connection info...${NC}"
HOST=$(tailscale --socket $TS_SOCK status --json | jq -r '.Self.DNSName' | sed 's/\.$//')
V4=$(tailscale --socket "$TS_SOCK" ip -4 2>/dev/null | head -n1)
V6=$(tailscale --socket "$TS_SOCK" ip -6 2>/dev/null | head -n1)

# Setup Tailscale serve to map port 80 to our local goosed
echo -e "${GREEN}Setting up Tailscale serve (port 80 → localhost:${PORT})...${NC}"
tailscale --socket "$TS_SOCK" serve reset >/dev/null 2>&1 || true
tailscale --socket "$TS_SOCK" serve --tcp=80 127.0.0.1:$PORT >/dev/null &
TAILSCALE_SERVE_PID=$!

# Use MagicDNS as the primary URL, fallback to IPv4 if no MagicDNS
if [[ -n "$HOST" && "$HOST" != "null" ]]; then
    TUNNEL_URL="http://$HOST"
    CONNECT_URL="$HOST:80"
elif [[ -n "$V4" ]]; then
    TUNNEL_URL="http://$V4"
    CONNECT_URL="$V4:80"
else
    echo -e "${RED}Error: No Tailscale IP addresses available${NC}"
    exit 1
fi

echo "IP V4 is $V4"

echo -e "${GREEN}✓ Tailscale serve established (PID: $TAILSCALE_SERVE_PID)${NC}"

# Create the configuration JSON for the QR code
CONFIG_JSON="{\"url\":\"http://${V4}\",\"secret\":\"${SECRET}\"}"

# URL encode the config JSON
URL_ENCODED_CONFIG=$(printf %s "$CONFIG_JSON" | jq -sRr @uri)

# Create the app URL for deep linking (matching tunnel.ts format)
APP_URL="goosechat://configure?data=${URL_ENCODED_CONFIG}"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     Connection Information                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Tailscale URL:${NC}  $TUNNEL_URL"
echo -e "${GREEN}Connect URL:${NC}    $CONNECT_URL"
echo -e "${GREEN}Secret Key:${NC}     $SECRET"
echo -e "${GREEN}Local Port:${NC}     $PORT"
if [[ -n "$HOST" && "$HOST" != "null" ]]; then
    echo -e "${GREEN}MagicDNS:${NC}      $HOST"
fi
if [[ -n "$V4" ]]; then
    echo -e "${GREEN}IPv4:${NC}          $V4"
fi
if [[ -n "$V6" ]]; then
    echo -e "${GREEN}IPv6:${NC}          $V6"
fi
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                          QR Code (Scan Me!)                        ║${NC}"
echo -e "${BLUE}╚════════════════════ tailscale══════════════════════════════════════════╝${NC}"
echo ""

# Generate and display QR code in terminal
qrencode -t ANSIUTF8 "$APP_URL"

echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}App URL:${NC} $APP_URL"
echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${GREEN}✓ Everything is running!${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop the server and Tailscale serve${NC}"
echo ""

# Keep the script running
wait
