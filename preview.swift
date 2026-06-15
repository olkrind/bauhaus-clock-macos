// Standalone preview app — no ScreenSaver framework needed.
// Build:  ./build-preview.sh
// Run:    ./build/BauhausPreview

import AppKit

// MARK: - Clock View

class ClockView: NSView {
    var palette: ClockPalette = Palettes.dials["Noir"]!
    var dialName = "Noir"
    var clockSize = "Classic"
    var showSeconds = true
    var night = false
    var lumeName = "Tritium Green"
    var movement = "Mechanical"

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(palette.bg.cgC)
        ctx.fill(bounds)

        ClockRenderer.draw(
            in: ctx,
            size: bounds.size,
            pal: palette,
            now: Date(),
            clockSize: clockSize,
            showSeconds: showSeconds,
            night: night,
            movement: movement
        )
    }

    func applySettings() {
        if night {
            palette = Palettes.nightPalette(lume: lumeName)
        } else {
            palette = Palettes.dials[dialName] ?? Palettes.dials["Noir"]!
        }
        needsDisplay = true
    }
}

// MARK: - Settings Panel Controller

class SettingsController: NSObject {
    let clockView: ClockView
    let window: NSWindow
    let panel: NSPanel

    private var dialPopup: NSPopUpButton!
    private var lumePopup: NSPopUpButton!
    private var sizePopup: NSPopUpButton!
    private var movementPopup: NSPopUpButton!
    private var nightCheck: NSButton!
    private var secondsCheck: NSButton!
    private var lumeLabel: NSTextField!

    init(clockView: ClockView, window: NSWindow) {
        self.clockView = clockView
        self.window = window

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 280),
            styleMask: [.titled, .closable, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Settings"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false

        super.init()
        buildUI()
        syncFromClockView()
    }

    private func buildUI() {
        let content = NSView(frame: panel.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        panel.contentView = content

        var y: CGFloat = 240

        // Dial
        y = addRow(to: content, label: "Dial", y: y) { frame in
            let popup = NSPopUpButton(frame: frame, pullsDown: false)
            popup.addItems(withTitles: Palettes.dialNames)
            popup.target = self
            popup.action = #selector(dialChanged(_:))
            self.dialPopup = popup
            return popup
        }

        // Size
        y = addRow(to: content, label: "Size", y: y) { frame in
            let popup = NSPopUpButton(frame: frame, pullsDown: false)
            popup.addItems(withTitles: ["Classic", "Compact"])
            popup.target = self
            popup.action = #selector(sizeChanged(_:))
            self.sizePopup = popup
            return popup
        }

        // Movement
        y = addRow(to: content, label: "Move", y: y) { frame in
            let popup = NSPopUpButton(frame: frame, pullsDown: false)
            popup.addItems(withTitles: ["Quartz", "Mechanical", "Digital"])
            popup.target = self
            popup.action = #selector(self.movementChanged(_:))
            self.movementPopup = popup
            return popup
        }

        // Seconds
        y = addRow(to: content, label: "", y: y) { frame in
            let btn = NSButton(checkboxWithTitle: "Show Seconds", target: self, action: #selector(secondsChanged(_:)))
            btn.frame = frame
            self.secondsCheck = btn
            return btn
        }

        // Night
        y = addRow(to: content, label: "", y: y) { frame in
            let btn = NSButton(checkboxWithTitle: "Night Mode", target: self, action: #selector(nightChanged(_:)))
            btn.frame = frame
            self.nightCheck = btn
            return btn
        }

        // Lume
        let lumeL = NSTextField(labelWithString: "Lume")
        lumeL.frame = NSRect(x: 16, y: y - 4, width: 50, height: 20)
        lumeL.font = NSFont.systemFont(ofSize: 12)
        content.addSubview(lumeL)
        self.lumeLabel = lumeL

        let lumeP = NSPopUpButton(frame: NSRect(x: 72, y: y - 4, width: 170, height: 24), pullsDown: false)
        lumeP.addItems(withTitles: Palettes.lumeNames)
        lumeP.target = self
        lumeP.action = #selector(lumeChanged(_:))
        content.addSubview(lumeP)
        self.lumePopup = lumeP
    }

    private func addRow(to parent: NSView, label: String, y: CGFloat,
                        builder: (NSRect) -> NSView) -> CGFloat {
        let rowY = y - 4
        if !label.isEmpty {
            let lbl = NSTextField(labelWithString: label)
            lbl.frame = NSRect(x: 16, y: rowY, width: 50, height: 20)
            lbl.font = NSFont.systemFont(ofSize: 12)
            parent.addSubview(lbl)
        }
        let ctrl = builder(NSRect(x: 72, y: rowY, width: 170, height: 24))
        parent.addSubview(ctrl)
        return y - 34
    }

    private func syncFromClockView() {
        dialPopup.selectItem(withTitle: clockView.dialName)
        sizePopup.selectItem(withTitle: clockView.clockSize)
        movementPopup.selectItem(withTitle: clockView.movement)
        secondsCheck.state = clockView.showSeconds ? .on : .off
        nightCheck.state = clockView.night ? .on : .off
        lumePopup.selectItem(withTitle: clockView.lumeName)
        updateLumeVisibility()
    }

    private func updateLumeVisibility() {
        let show = nightCheck.state == .on
        lumePopup.isEnabled = show
        lumeLabel.textColor = show ? .labelColor : .tertiaryLabelColor
    }

    private func updateTitle() {
        if clockView.night {
            window.title = "Bauhaus Clock — Night (\(clockView.lumeName))"
        } else {
            window.title = "Bauhaus Clock — \(clockView.dialName)"
        }
    }

    @objc func dialChanged(_ sender: NSPopUpButton) {
        clockView.dialName = sender.titleOfSelectedItem ?? "Noir"
        clockView.applySettings()
        updateTitle()
    }

    @objc func sizeChanged(_ sender: NSPopUpButton) {
        clockView.clockSize = sender.titleOfSelectedItem ?? "Classic"
        clockView.applySettings()
    }

    @objc func movementChanged(_ sender: NSPopUpButton) {
        clockView.movement = sender.titleOfSelectedItem ?? "Mechanical"
        clockView.applySettings()
    }

    @objc func secondsChanged(_ sender: NSButton) {
        clockView.showSeconds = sender.state == .on
        clockView.applySettings()
    }

    @objc func nightChanged(_ sender: NSButton) {
        clockView.night = sender.state == .on
        clockView.applySettings()
        updateLumeVisibility()
        updateTitle()
    }

    @objc func lumeChanged(_ sender: NSPopUpButton) {
        clockView.lumeName = sender.titleOfSelectedItem ?? "Tritium Green"
        clockView.applySettings()
        updateTitle()
    }

    @objc func showPanel() {
        // Position panel to the right of the main window
        let mainFrame = window.frame
        let panelFrame = panel.frame
        let origin = NSPoint(
            x: mainFrame.maxX + 12,
            y: mainFrame.midY - panelFrame.height / 2
        )
        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
    }
}

// MARK: - Toolbar Delegate

class ToolbarDelegate: NSObject, NSToolbarDelegate {
    let settingsController: SettingsController

    init(settingsController: SettingsController) {
        self.settingsController = settingsController
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if itemIdentifier.rawValue == "settings" {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Settings"
            item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
            item.target = settingsController
            item.action = #selector(SettingsController.showPanel)
            return item
        }
        return nil
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, NSToolbarItem.Identifier("settings")]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, NSToolbarItem.Identifier("settings")]
    }
}

// MARK: - App Entry Point

@main
struct PreviewApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 540),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Bauhaus Clock — Noir"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 200, height: 200)
        window.aspectRatio = NSSize(width: 1, height: 1)

        let clockView = ClockView(frame: window.contentView!.bounds)
        clockView.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(clockView)

        // Parse CLI args (still works as before)
        let args = CommandLine.arguments
        func argValue(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        if let dial = argValue("--dial") {
            clockView.dialName = dial
        }
        if args.contains("--night") {
            clockView.night = true
            if let lume = argValue("--lume") { clockView.lumeName = lume }
        }
        if args.contains("--no-seconds") { clockView.showSeconds = false }
        if args.contains("--compact") { clockView.clockSize = "Compact" }
        if let mv = argValue("--movement") { clockView.movement = mv }
        clockView.applySettings()

        // Settings panel + toolbar gear button
        let settingsCtrl = SettingsController(clockView: clockView, window: window)
        let toolbarDelegate = ToolbarDelegate(settingsController: settingsCtrl)

        let toolbar = NSToolbar(identifier: "PreviewToolbar")
        toolbar.delegate = toolbarDelegate
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

        // Keep references alive
        let refs: [AnyObject] = [settingsCtrl, toolbarDelegate]
        withExtendedLifetime(refs) {
            // 60fps redraw timer
            Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
                clockView.needsDisplay = true
            }

            window.makeKeyAndOrderFront(nil)
            app.activate(ignoringOtherApps: true)

            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { _ in
                app.terminate(nil)
            }

            app.run()
        }
    }
}
