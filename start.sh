
# MacBook-Air-2:greenlep_gta work$ bash start.sh 
# Port 8080 is busy, trying 8081...

#   GreenLEP GTA — serving at:
#   http://localhost:8081

#   Press Ctrl+C to stop.

# Serving HTTP on 127.0.0.1 port 8081 (http://127.0.0.1:8081/) ...




#!/usr/bin/env bash
# Serve the GreenLEP GTA static site locally
set -euo pipefail

PORT="${1:-8080}"

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

python3 -m http.server "$PORT" --bind 127.0.0.1
