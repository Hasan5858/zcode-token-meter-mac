# TokenMeter for ZCode (macOS)

A floating, always-on-top macOS widget for [ZCode](https://zcode.z.ai) that shows live token-generation speed and prompt-cache hit rate while the agent works.

```
● 62.2 tok/s    cache 87%
```

Inspired by [alixntuyt-eng/zcode-token-meter](https://github.com/alixntuyt-eng/zcode-token-meter) (Windows/WPF) — this is a native Swift/AppKit implementation for macOS.

## Features

- **tok/s** — live generation speed while a turn is running, last request's speed when idle (right-click → toggle tok/min)
- **cache hit %** — session-wide `cache_read / input_tokens`, matching ZCode's Developer tools → Token debug "Average hit"
- **LIVE/IDLE dot** — green while the model is generating, gray when idle
- **ZCode-only visibility** — shows only while ZCode is the frontmost app, hides everywhere else
- **Session picker** — right-click → pick any of your recent 10 chats to pin its stats, or "Auto"
- **Auto chat tracking** — follows the chat you last sent a message in
- **Drag to position** — position is remembered; unit preference and pinned session too
- **Private by design** — reads ZCode's local SQLite DB (`~/.zcode/cli/db/db.sqlite`) read-only. No network, no telemetry, no code execution.

## Requirements

- macOS 13+ (Apple Silicon or Intel)
- ZCode desktop app
- Xcode Command Line Tools (`xcode-select --install`) — only needed for building

## Install

### Option A — build & run manually

```bash
git clone <this-repo>
cd <this-repo>/zcode-token-meter-mac/scripts
chmod +x build.sh launch.sh stop.sh
./launch.sh
```

The first launch compiles the widget with `swiftc` and starts it. Stop it any time with:

```bash
./stop.sh
```

### Option B — as a ZCode plugin (auto-start with every ZCode session)

1. Open ZCode → **Settings → Plugins → Create → Add marketplace**
2. Point it at this repository (or a local clone of this folder — it is a marketplace root containing `marketplace.json`)
3. Install **TokenMeter (macOS)** from the marketplace
4. Restart ZCode — the bundled `SessionStart` hook launches the widget in the background on every session

### Auto-start on ZCode launch (without installing the plugin)

Add this to `~/.zcode/cli/config.json` (create the file if it doesn't exist):

```json
{
  "hooks": {
    "enabled": true,
    "events": {
      "SessionStart": [
        {
          "hooks": [
            {
              "type": "process",
              "command": "/bin/bash",
              "args": ["/absolute/path/to/zcode-token-meter-mac/scripts/launch.sh"],
              "enabled": true,
              "timeoutMs": 15000
            }
          ]
        }
      ]
    }
  }
}
```

> The launch script spawns the widget with `start_new_session` (detached). If you replace it with a plain `nohup ... &`, a widget launched from a hook dies ~1 second later — ZCode kills the hook's process group when the hook finishes.

## How it reads your data

The widget opens `~/.zcode/cli/db/db.sqlite` (read-write flags required for fresh WAL snapshots — a read-only connection serves stale data) and queries the `model_usage` table:

- speed = `output_tokens / (completed_at − first_token_at)` — per model request, excluding tool-call wait time, so it matches the provider-reported tok/s
- cache % = `Σ cache_read_input_tokens / Σ input_tokens` — note ZCode's `input_tokens` already *includes* cached tokens; averaging per-request values double-counts and skews low

## Optional: per-chat auto tracking

ZCode gives no signal when you switch chats, so the widget cannot know which chat you are looking at. Two practical workarounds:

1. **Session picker** (built in) — right-click the widget and pin any recent chat
2. **Prompt-submit hook** — add a `UserPromptSubmit` hook that writes the current `session_id` to `~/.zcode/token-meter/current-session`; Auto mode reads it first. See the hook above for the exact format (event: `UserPromptSubmit`, a short `python3 -c` script parsing stdin JSON).

## Known limitations

- Focused-tab detection is not possible: ZCode's Electron accessibility tree is disabled, and the DB never records which chat is open
- Brand-new chats show `no data yet` until their first turn completes
- The widget is a floating NSPanel — it cannot inject stats into ZCode's own toolbar (plugins cannot extend native app UI)

## License

MIT — see [LICENSE](LICENSE).
