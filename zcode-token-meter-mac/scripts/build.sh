#!/bin/bash
# Compile the TokenMeter widget. Safe to re-run; skips if already built.
# Run with: bash build.sh  (exec bit not required — installer strips it)
set -euo pipefail
cd "$(dirname "$0")"
if [ -x ./token-meter ] && [ ./token-meter -nt ./TokenMeter.swift ]; then
  exit 0
fi
swiftc -O -o token-meter TokenMeter.swift
echo "TokenMeter built."
