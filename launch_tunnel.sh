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
echo -e "${BLUE}║                     Goose Remote Access Setup                      ║${NC}"
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

# Check if cloudflared is available
if ! command -v cloudflared &> /dev/null; then
    echo -e "${RED}Error: cloudflared is not installed${NC}"
    echo -e "${YELLOW}Install it with: brew install cloudflared${NC}"
    exit 1
fi

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Shutting down...${NC}"
    if [ ! -z "$GOOSED_PID" ]; then
        echo "Stopping goosed (PID: $GOOSED_PID)"
        kill $GOOSED_PID 2>/dev/null || true
    fi
    if [ ! -z "$TUNNEL_PID" ]; then
        echo "Stopping tunnel (PID: $TUNNEL_PID)"
        kill $TUNNEL_PID 2>/dev/null || true
    fi
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

# Create Cloudflare tunnel and capture the URL
echo -e "${GREEN}Creating Cloudflare tunnel...${NC}"
TUNNEL_LOG=$(mktemp)
cloudflared tunnel --url "http://localhost:${PORT}" > "$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!

# Wait for tunnel URL to appear in the log
echo "Waiting for tunnel URL..."
TUNNEL_URL=""
for i in {1..30}; do
    # Look for lines like: "https://randomly-generated-name.trycloudflare.com"
    if grep -q "https://.*\.trycloudflare\.com" "$TUNNEL_LOG" 2>/dev/null; then
        TUNNEL_URL=$(grep -o "https://[a-z0-9-]*\.trycloudflare\.com" "$TUNNEL_LOG" | head -1)
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: Failed to get tunnel URL${NC}"
        cat "$TUNNEL_LOG"
        rm -f "$TUNNEL_LOG"
        exit 1
    fi
    sleep 0.5
done

rm -f "$TUNNEL_LOG"

if [ -z "$TUNNEL_URL" ]; then
    echo -e "${RED}Error: Could not extract tunnel URL${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Cloudflare tunnel established (PID: $TUNNEL_PID)${NC}"

# Format the connection URL (remove https:// and add :443)
CONNECT_URL="${TUNNEL_URL#https://}:443"

# Create the configuration JSON for the QR code
CONFIG_JSON="{\"url\":\"${CONNECT_URL}\",\"secret\":\"${SECRET}\"}"

# URL encode the config JSON
URL_ENCODED_CONFIG=$(printf %s "$CONFIG_JSON" | jq -sRr @uri)

# Create the app URL for deep linking (matching tunnel.ts format)
APP_URL="goosechat://configure?data=${URL_ENCODED_CONFIG}"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     Connection Information                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Tunnel URL:${NC}     $TUNNEL_URL"
echo -e "${GREEN}Connect URL:${NC}    $CONNECT_URL"
echo -e "${GREEN}Secret Key:${NC}     $SECRET"
echo -e "${GREEN}Local Port:${NC}     $PORT"
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                          QR Code (Scan Me!)                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Generate and display QR code in terminal
qrencode -t ANSIUTF8 "$APP_URL"

echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}App URL:${NC} $APP_URL"
echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${GREEN}✓ Everything is running!${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop the server and tunnel${NC}"
echo ""

# Keep the script running
wait
