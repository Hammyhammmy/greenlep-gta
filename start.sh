#!/usr/bin/env bash
# Serve the GreenLEP GTA static site locally
set -euo pipefail

PORT=8080

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port|-p) PORT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: bash start.sh [--port PORT]"
      echo "  --port, -p  Port to serve on (default: 8080)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Find a free port if requested one is busy
while lsof -iTCP:"$PORT" -sTCP:LISTEN &>/dev/null; do
  echo "Port $PORT is busy, trying $((PORT + 1))..."
  PORT=$((PORT + 1))
done

echo ""
echo "  GreenLEP GTA — serving at:"
echo "  http://localhost:$PORT"
echo ""
echo "  Press Ctrl+C to stop."
echo ""

# Auto-open in browser
open "http://localhost:$PORT" 2>/dev/null || true

python3 -m http.server "$PORT" --bind 127.0.0.1
