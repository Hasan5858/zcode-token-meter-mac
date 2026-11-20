# zcode-token-meter-mac

A floating, always-on-top macOS widget for [ZCode](https://zcode.z.ai) that shows live token-generation speed and prompt-cache hit rate while the agent works.

```
● 62.2 tok/s    cache 87%
```

Native Swift/AppKit port of [alixntuyt-eng/zcode-token-meter](https://github.com/alixntuyt-eng/zcode-token-meter) (which is Windows/WPF-only).

## Install (one minute)

This repository is a ZCode plugin marketplace — install straight from the app:

1. Open **ZCode → Settings → Plugins**
2. Click **Create → Add marketplace**
3. Paste this repository: `Hasan5858/zcode-token-meter-mac`
4. Under **Personal → zcode-token-meter-mac**, click **Install** on **TokenMeter (macOS)**
5. Restart ZCode — the widget starts automatically with every session

Requirements: macOS 13+, [ZCode desktop](https://zcode.z.ai), Xcode Command Line Tools (`xcode-select --install`) for the first build.

## What you get

- **tok/s** live generation speed (right-click → toggle tok/min)
- **cache hit %** matching ZCode's Developer tools → Token debug panel
- **LIVE/IDLE dot** while the model generates
- **ZCode-only visibility** — hides when you focus any other app
- **Session picker** — right-click to pin any of your recent 10 chats
- **Auto chat tracking** — follows the chat you last messaged in
- Drag to move; position, unit and pinned session are remembered
- **No network, no telemetry** — reads ZCode's local SQLite DB only

Details, manual install, troubleshooting and the data-formula documentation: [plugin README](zcode-token-meter-mac/README.md).

## License

MIT — see [LICENSE](LICENSE).
