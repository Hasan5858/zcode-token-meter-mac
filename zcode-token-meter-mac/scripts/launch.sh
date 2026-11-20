#!/bin/bash
# Build (if needed) and launch the TokenMeter widget. No-op if already running.
#
# The widget is spawned in a NEW SESSION (start_new_session=True) so that,
# when launched from a ZCode SessionStart hook, it survives ZCode's
# hook process-group cleanup — a plain `nohup ... &` child gets killed
# about a second after the hook returns.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

if ! pgrep -x token-meter >/dev/null 2>&1; then
  if [ ! -x "$DIR/token-meter" ]; then
    "$DIR/build.sh"
  fi
  python3 -c "import subprocess; subprocess.Popen(['$DIR/token-meter'], cwd='$DIR', stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)"
fi
