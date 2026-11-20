feat(zcode-token-meter-mac): add macOS floating token/cache widget

## Problem solved

ZCode's Developer tools → Token debug panel shows per-chat token stats, but only while you have that chat open. There is no always-visible way to see generation speed and cache efficiency while working in any chat.

## What the plugin adds

- A floating, always-on-top macOS widget (native Swift/AppKit, compiled on-host with swiftc): live tok/s (toggle tok/min), session-wide cache hit %, LIVE/IDLE dot, drag-position memory, ZCode-frontmost-only visibility.
- Hooks: `SessionStart` (auto-launch detached, record session id) and `UserPromptSubmit` (track the chat the user messaged in).
- Command: `/tokenmeter` (start/stop/status).
- Right-click session picker to pin any of the recent 10 chats.

## Tested behavior

- Marketplace install on ZCode desktop (macOS, Apple Silicon): add marketplace → install → restart → widget auto-launches, tracks chat switches, hides outside ZCode. Verified by a clean normal-user flow.
- Stripped-permissions install scenario (files rw-r--r--) verified: scripts run via `bash`, launch.sh self-heals.
- Build-failure path verified: missing/failing swiftc writes `~/.zcode/token-meter/build-error.log` and posts a local notification (the CLT shim hangs without this guard — 300s timeout added).

## Version & registration changes

- Adds `external_plugins/zcode-token-meter-mac/` (v0.1.6, `.zcode-plugin/plugin.json` + README.md + README_CN.md + LICENSE)
- Registers a root `marketplace.json` entry with matching name/version/description

## Dependencies & side effects

- Requires macOS 13+ and Xcode Command Line Tools (compile-on-first-run; no prebuilt binary committed)
- Reads ZCode's local `~/.zcode/cli/db/db.sqlite` once per second (read)
- Writes only under `~/.zcode/token-meter/` and the compiled binary next to its source
- Hooks run two short `python3 -c` one-liners and `/bin/bash scripts/launch.sh`; build failure posts a local `osascript` notification
- **No network access, no telemetry**

## Third-party licensing

MIT (c) 2026 Hasan Sarker. Inspired by alixntuyt-eng/zcode-token-meter (Windows/WPF, separate project); no code reused.

## Plugin type

**Standard plugin** — no MCP Apps interactive page (`ui.surfaces`/`_meta.ui.resourceUri` not used).
