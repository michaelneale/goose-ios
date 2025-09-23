#!/bin/bash

# Kill any existing goosed processes
killall goosed 2>/dev/null

# Wait a moment for processes to terminate
sleep 1

# Launch goosed with required environment variables
export GOOSE_SERVER__SECRET_KEY="test"
export GOOSE_PORT=62996
export GOOSE_PROVIDER="databricks"
export GOOSE_MODEL="goose-claude-4-sonnet"

# Set databricks credentials from config if available
if [ -f "$HOME/.config/goose/config.yaml" ]; then
    export DATABRICKS_HOST=$(grep "DATABRICKS_HOST:" "$HOME/.config/goose/config.yaml" | cut -d' ' -f2)
fi

echo "Starting goosed with the following configuration:"
echo "  Secret Key: $GOOSE_SERVER__SECRET_KEY"
echo "  Port: $GOOSE_PORT"
echo "  Provider: $GOOSE_PROVIDER"
echo "  Model: $GOOSE_MODEL"
echo "  Databricks Host: $DATABRICKS_HOST"
echo ""

# Start goosed in the background
/Users/dhanji/src/goose/target/release/goosed agent &

# Get the process ID
GOOSED_PID=$!

echo "goosed started with PID: $GOOSED_PID"
echo "Server should be available at: http://127.0.0.1:$GOOSE_PORT"
echo ""
echo "To stop the server, run: kill $GOOSED_PID"
echo "Or use: killall goosed"

# Wait a moment and check if the process is still running
sleep 2
if kill -0 $GOOSED_PID 2>/dev/null; then
    echo "✅ goosed is running successfully"
else
    echo "❌ goosed failed to start"
    exit 1
fi
