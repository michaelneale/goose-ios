#!/bin/bash

# GooseCode Launch Script
echo "🪿 Launching GooseCode..."

# Start local server for enhanced features
python3 -m http.server 8000 &
SERVER_PID=$!
sleep 2

# Check if we're on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Opening GooseCode Pro in default browser (macOS)..."
    open "http://localhost:8000/integrated-goosecode.html"
    echo "Opening Canvas demo in new tab..."
    sleep 2
    open "http://localhost:8000/demo.html"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Opening in default browser (Linux)..."
    xdg-open "http://localhost:8000/integrated-goosecode.html"
    sleep 2
    xdg-open "http://localhost:8000/demo.html"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    echo "Opening in default browser (Windows)..."
    start "http://localhost:8000/integrated-goosecode.html"
    sleep 2
    start "http://localhost:8000/demo.html"
else
    echo "Please open http://localhost:8000/integrated-goosecode.html in your web browser manually."
fi

echo "✅ GooseCode Pro launched successfully!"
echo ""
echo "🚀 Enhanced Features:"
echo "   • Enhanced AI chat with code analysis"
echo "   • Real-time error checking and suggestions"
echo "   • Smart auto-completion (Tab key)"
echo "   • Advanced VIM commands (:zen, :ai, :template)"
echo "   • Project export/import functionality"
echo "   • Template selector with game/viz examples"
echo "   • Focus and Zen modes for distraction-free coding"
echo ""
echo "🎯 Quick Start:"
echo "   • Press ':' for VIM-style command palette"
echo "   • Use Ctrl/Cmd+1/2/3 to switch view modes"
echo "   • Chat with enhanced AI agent (left sidebar)"
echo "   • Try Canvas demo for interactive examples"
echo "   • Export your projects with the Export button"
echo ""
echo "📖 See README.md for full documentation"
echo "🔧 Configure AI API key in ai-config.js for real GPT-5 integration"

# Keep server running
wait $SERVER_PID
