// TokenMeter — simple floating always-on-top widget for ZCode on macOS.
// Shows tok/s and prompt-cache hit rate. Read-only from
// ~/.zcode/cli/db/db.sqlite. No network, no telemetry.
// This is the proven-visible v1 design: plain view, solid fill, text fields.

import AppKit
import SQLite3

let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class MeterView: NSView {
    let statusDot  = NSTextField(labelWithString: "●")
    let speedField = NSTextField(labelWithString: "— tok/s")
    let cacheField = NSTextField(labelWithString: "cache —")
    var onRightClick: (() -> Void)?

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.12, alpha: 0.55).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()
    }

    func setup() {
        statusDot.font = .systemFont(ofSize: 12)
        speedField.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        speedField.textColor = .white
        cacheField.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        cacheField.textColor = NSColor(calibratedWhite: 0.72, alpha: 1)

        for f in [statusDot, speedField, cacheField] {
            f.translatesAutoresizingMaskIntoConstraints = false
            addSubview(f)
        }

        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            statusDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            speedField.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 7),
            speedField.centerYAnchor.constraint(equalTo: centerYAnchor),
            cacheField.leadingAnchor.constraint(greaterThanOrEqualTo: speedField.trailingAnchor, constant: 14),
            cacheField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            cacheField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

final class MeterPanel: NSPanel {
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: backing, defer: flag)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let panelWidth: CGFloat = 235
    let panelHeight: CGFloat = 36
    var panel: MeterPanel!
    var view: MeterView!
    var timer: Timer?
    var db: OpaquePointer?
    var usePerMinute = UserDefaults.standard.object(forKey: "TokenMeterUnitPerMinute") as? Bool ?? false
    // nil = Auto (hook-tracked chat); otherwise a locked session id from the picker.
    var lockedSession: String? = UserDefaults.standard.string(forKey: "TokenMeterLockedSession")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let frame: NSRect? = UserDefaults.standard.string(forKey: "TokenMeterFrame")
            .flatMap { NSRectFromString($0) }
        // Default: the input-toolbar spot in ZCode (user-chosen home).
        let screen = NSScreen.main!.frame
        let rect = frame ?? NSRect(x: screen.maxX - panelWidth - 344,
                                   y: 93,
                                   width: panelWidth, height: panelHeight)
        panel = MeterPanel(contentRect: rect, styleMask: [], backing: .buffered, defer: false)
        view = MeterView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        view.setup()
        view.onRightClick = { [weak self] in self?.showMenu() }
        panel.contentView = view
        panel.orderFrontRegardless()

        openDB()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateVisibility()
            self?.refresh()
        }
        updateVisibility()
        refresh()
    }

    // Show the widget only while ZCode is the frontmost app.
    var isShown = true
    func updateVisibility() {
        let zcodeActive = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "dev.zcode.app"
        if zcodeActive != isShown {
            isShown = zcodeActive
            if zcodeActive { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        }
    }

    deinit { if let db { sqlite3_close(db) } }

    func openDB() {
        let path = NSHomeDirectory() + "/.zcode/cli/db/db.sqlite"
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            sqlite3_close(handle)
            return
        }
        db = handle
    }

    func mostRecentSessionId() -> String {
        guard let db else { return "" }
        sqlite3_exec(db, "PRAGMA wal_checkpoint(PASSIVE);", nil, nil, nil)
        var stmt: OpaquePointer?
        let sql = "SELECT session_id FROM model_usage ORDER BY started_at DESC LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return "" }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) else { return "" }
        return String(cString: c)
    }

    func fetchRows(sessionId: String) -> [[String]] {
        guard let db else { return [] }
        sqlite3_exec(db, "PRAGMA wal_checkpoint(PASSIVE);", nil, nil, nil)
        // model_usage = per-REQUEST rows: a new completed row lands every few
        // seconds while a turn runs, so tok/s updates live. (turn_usage only
        // writes at turn end — using it froze the display mid-turn.)
        let sql = """
        SELECT session_id, status, first_token_at, completed_at, output_tokens,
               input_tokens, cache_read_input_tokens
        FROM model_usage WHERE session_id = ? ORDER BY started_at DESC LIMIT 200
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionId, -1, transient)
        var rows: [[String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String] = []
            for i in 0..<sqlite3_column_count(stmt) {
                if let c = sqlite3_column_text(stmt, i) { row.append(String(cString: c)) }
                else { row.append("") }
            }
            rows.append(row)
        }
        return rows // newest first
    }

    func refresh() {
        // Resolve which chat to show: picker lock > most-recent activity.
        // "Most recent" is exactly the running/latest session (newest
        // model_usage row), so Auto always grabs whatever is actually
        // working right now. (The prompt-hook file was removed from this
        // chain: "last typed chat" and "currently running chat" differ
        // whenever a resumed/other session is working, and running wins.)
        let activeSession = lockedSession ?? mostRecentSessionId()

        let rows = activeSession.isEmpty ? [] : fetchRows(sessionId: activeSession)
        if rows.isEmpty {
            // Selected/hooked chat has no turns yet (e.g. brand-new chat).
            view.speedField.stringValue = "no data yet"
            view.cacheField.stringValue = ""
            view.statusDot.textColor = .systemGray
            return
        }
        let sessionRows = rows

        let running = sessionRows.contains { $0[1] == "running" }
        // Per-request speed: each model request completes every few seconds
        // during a turn, so this value refreshes continuously.
        var speed: Double = 0
        if let done = sessionRows.first(where: { $0[1] == "completed" }),
           let s = Int64(done[2]), let c = Int64(done[3]), c > s {
            speed = (Double(done[4]) ?? 0) / max(1.0, Double(c - s) / 1000.0)
        }

        let value = usePerMinute ? speed * 60 : speed
        view.speedField.stringValue = String(format: "%.1f %@", value, usePerMinute ? "tok/min" : "tok/s")

        // model_usage input_tokens already includes cached tokens → hit = read/input.
        let read = sessionRows.reduce(Int64(0)) { $0 + (Int64($1[6]) ?? 0) }
        let totalInput = sessionRows.reduce(Int64(0)) { $0 + (Int64($1[5]) ?? 0) }
        view.cacheField.stringValue = totalInput > 0
            ? String(format: "cache %.0f%%", Double(read) / Double(totalInput) * 100)
            : "cache —"

        view.statusDot.textColor = running ? .systemGreen : .systemGray
    }

    func querySessions() -> [(String, String)] {
        guard let db else { return [] }
        sqlite3_exec(db, "PRAGMA wal_checkpoint(PASSIVE);", nil, nil, nil)
        let sql = """
        SELECT mu.session_id, s.title, max(mu.started_at)
        FROM model_usage mu JOIN session s ON s.id = mu.session_id
        WHERE mu.session_id NOT LIKE 'sess_subagent_%'
        GROUP BY mu.session_id ORDER BY max(mu.started_at) DESC LIMIT 10
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [(String, String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c0 = sqlite3_column_text(stmt, 0), let c1 = sqlite3_column_text(stmt, 1) {
                out.append((String(cString: c0), String(cString: c1)))
            }
        }
        return out
    }

    func showMenu() {
        let menu = NSMenu()

        let auto = NSMenuItem(title: "Auto (follow your chats)",
                              action: #selector(pickAuto), keyEquivalent: "")
        auto.target = self
        auto.state = lockedSession == nil ? .on : .off
        menu.addItem(auto)

        for (sid, title) in querySessions() {
            let short = title.count > 42 ? String(title.prefix(42)) + "…" : title
            let item = NSMenuItem(title: short, action: #selector(pickSession(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = sid
            item.state = lockedSession == sid ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let unitItem = NSMenuItem(title: usePerMinute ? "Show tok/s" : "Show tok/min",
                                  action: #selector(toggleUnit), keyEquivalent: "")
        unitItem.target = self
        menu.addItem(unitItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit TokenMeter", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }
    }

    @objc func toggleUnit() {
        usePerMinute.toggle()
        UserDefaults.standard.set(usePerMinute, forKey: "TokenMeterUnitPerMinute")
        refresh()
    }

    @objc func pickAuto() {
        lockedSession = nil
        UserDefaults.standard.removeObject(forKey: "TokenMeterLockedSession")
        refresh()
    }

    @objc func pickSession(_ sender: NSMenuItem) {
        lockedSession = sender.representedObject as? String
        UserDefaults.standard.set(lockedSession, forKey: "TokenMeterLockedSession")
        refresh()
    }

    @objc func quit() {
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "TokenMeterFrame")
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
