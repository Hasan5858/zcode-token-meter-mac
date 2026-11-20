#!/bin/bash
# Stop the TokenMeter widget.
DIR="$(cd "$(dirname "$0")" && pwd)"
pkill -f "$DIR/token-meter" 2>/dev/null || true
echo "TokenMeter stopped."
