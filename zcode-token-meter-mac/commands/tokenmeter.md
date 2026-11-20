---
description: Control the TokenMeter floating widget (status / start / stop)
---

Control the TokenMeter widget using the plugin scripts at `${CLAUDE_PLUGIN_ROOT}/scripts/`:

- **status**: `pgrep -fl "${CLAUDE_PLUGIN_ROOT}/scripts/token-meter"` and report running/not running.
- **start**: run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/launch.sh"` (builds on first run, then launches the floating widget).
- **stop**: run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/stop.sh"`.

Widget usage (tell the user): drag to reposition (position is remembered), right-click for the menu (toggle tok/s ↔ tok/min, quit). It auto-starts with new sessions via the SessionStart hook.
