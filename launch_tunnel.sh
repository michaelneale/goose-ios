#!/bin/bash

# Install required tools if not already installed
if ! command -v lt &> /dev/null; then
    echo "Installing localtunnel..."
    brew install localtunnel
fi

if ! command -v qrencode &> /dev/null; then
    echo "Installing qrencode..."
    brew install qrencode
fi

# Generate a secure random key (32 characters)
GOOSE_SECRET=$(openssl rand -base64 24)

# Export environment variables for goosed
export GOOSE_SERVER__SECRET_KEY="$GOOSE_SECRET"
export GOOSE_PORT=62996
export GOOSE_STANDALONE_MODE="true"

# Kill any existing goosed processes
killall goosed 2>/dev/null

# Kill any existing localtunnel processes
pkill -f "lt --port 62996" 2>/dev/null

# Wait a moment for processes to terminate
sleep 1

# Start goosed in the background
goosed agent &
GOOSED_PID=$!

echo "goosed started with PID: $GOOSED_PID"

# Wait a moment for goosed to start
sleep 2

# Start localtunnel and capture its output
echo "Starting localtunnel..."
lt --port 62996 2>&1 | tee /dev/tty | grep -m 1 "your url is: https://.*\.loca\.lt" | sed 's/your url is: //' > tunnel_url.txt &
LT_PID=$!

# Wait for the URL to be written
sleep 3

if [ -f tunnel_url.txt ]; then
    # Get base URL and remove any newlines
    CONNECT_URL="$(cat tunnel_url.txt | tr -d '\n'):443"
    
    # Create JSON-style data for QR code and URL scheme
    CONFIG_DATA="{\"url\":\"$CONNECT_URL\",\"secret\":\"$GOOSE_SECRET\"}"
    
    # URL encode the config data
    URL_ENCODED_CONFIG=$(echo -n "$CONFIG_DATA" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=''))")
    APP_URL="goosechat://configure?data=$URL_ENCODED_CONFIG"
    
    # Create QR code for the app URL
    echo $APP_URL | qrencode -o tunnel_qr.png -s 10
    
    # Display the QR code if running in terminal
    if [ -t 1 ]; then
        echo $APP_URL | qrencode -t ANSI
    fi
    
    # Open the QR code image
    open tunnel_qr.png
    
    # Print connection details after QR code
    echo ""
    echo "========== CONNECTION DETAILS =========="
    echo "URL:    $CONNECT_URL"
    echo "Secret: $GOOSE_SECRET"
    echo "App URL: $APP_URL"
    echo "====================================="
    echo ""
    echo "Scan the QR code with your camera to configure the app"
    echo ""
else
    echo "❌ Failed to get tunnel URL"
    exit 1
fi

echo "To stop all services:"
echo "kill $GOOSED_PID $LT_PID"
echo "Or use: killall goosed; pkill -f 'lt --port 62996'"

# Keep script running
wait
