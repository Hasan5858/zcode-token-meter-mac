#!/bin/bash
# Stop the TokenMeter widget. Run with: bash stop.sh
DIR="$(cd "$(dirname "$0")" && pwd)"
pkill -f "$DIR/token-meter" 2>/dev/null || pkill -x token-meter 2>/dev/null || true
echo "TokenMeter stopped."
