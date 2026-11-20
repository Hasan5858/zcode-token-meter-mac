#!/bin/bash
# Build (if needed) and launch the TokenMeter widget. No-op if already running.
#
# Notes:
# - Called via `/bin/bash launch.sh` — never rely on the executable bit:
#   ZCode's plugin installer strips exec permissions from installed files.
# - The widget is spawned in a NEW SESSION (start_new_session=True) so that,
#   when launched from a ZCode SessionStart hook, it survives ZCode's
#   hook process-group cleanup — a plain `nohup ... &` child gets killed
#   about a second after the hook returns.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

# Self-heal permissions stripped by the plugin installer (best-effort).
chmod +x "$DIR"/*.sh "$DIR/token-meter" 2>/dev/null || true

if ! pgrep -x token-meter >/dev/null 2>&1; then
  if [ ! -x "$DIR/token-meter" ]; then
    bash "$DIR/build.sh"
  fi
  python3 -c "import subprocess; subprocess.Popen(['$DIR/token-meter'], cwd='$DIR', stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)"
fi
