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

SECRET="test"

# Check if goosed is available in PATH
if ! command -v goosed &> /dev/null; then
    echo -e "${RED}Error: goosed not found in PATH${NC}"
    echo -e "${YELLOW}Please add goose/target/release to your PATH${NC}"
    echo -e "${YELLOW}Example: export PATH=\$PATH:${SCRIPT_DIR}/../goose/target/release${NC}"
    exit 1
fi

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Shutting down...${NC}"
    if [ ! -z "$GOOSED_PID" ]; then
        echo "Stopping goosed (PID: $GOOSED_PID)"
        kill $GOOSED_PID 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Start goosed in the background
echo -e "${GREEN}Starting goosed on port ${PORT}...${NC}"
export GOOSE_PORT=$PORT
export GOOSE_SERVER__SECRET_KEY="$SECRET"
goosed agent &
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

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     Connection Information                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}URL:${NC}        http://localhost:${PORT}"
echo -e "${GREEN}Secret Key:${NC} $SECRET"
echo ""
echo -e "${GREEN}✓ Goosed is running!${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo ""

# Keep the script running
wait
