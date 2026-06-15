import AppKit
import ScreenSaver

/// Native "Options…" configuration sheet for the screensaver.
///
/// Why this exists: on macOS Sonoma/Sequoia the screensaver runs inside the
/// sandboxed `legacyScreenSaver.appex`. Its `ScreenSaverDefaults` are redirected
/// into the appex container, which an external companion app cannot reach. The
/// only place writes land in the *same* store the saver reads is *inside* the
/// sandbox — i.e. from this sheet. So OK here actually sticks.
final class ConfigureSheetController: NSObject {

    /// Posted (cross-process) when the user commits new settings via OK, so the
    /// rendering instance — which runs in a *separate* process — can re-read and
    /// repaint without waiting for a fresh launch.
    static let configChangedNotification = Notification.Name("com.bauhausclk.BauhausClock.configChanged")

    private let defaults: UserDefaults?

    // Stored value lists
    private let appearanceTitles = ["Night", "Day", "Automatic"]
    private let appearanceValues = ["night", "day", "system"]
    private let sizeTitles = ["Classic", "Compact"]
    private let movementTitles = ["Quartz", "Mechanical", "Digital"]

    private var appearancePopup: NSPopUpButton!
    private var dialPopup: NSPopUpButton!
    private var lumePopup: NSPopUpButton!
    private var movementPopup: NSPopUpButton!
    private var sizePopup: NSPopUpButton!
    private var secondsCheck: NSButton!

    let window: NSWindow

    init(defaults: UserDefaults?) {
        self.defaults = defaults

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 310),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        w.title = "Bauhaus Clock"
        self.window = w

        super.init()

        buildUI()
        loadValues()
    }

    // MARK: - UI

    private func buildUI() {
        let content = window.contentView!
        var y: CGFloat = 270

        func addRow(_ label: String, _ control: NSView) {
            let l = NSTextField(labelWithString: label)
            l.frame = NSRect(x: 16, y: y, width: 90, height: 22)
            l.alignment = .right
            content.addSubview(l)
            control.frame = NSRect(x: 114, y: y - 2, width: 210, height: 26)
            content.addSubview(control)
            y -= 38
        }

        appearancePopup = NSPopUpButton()
        appearancePopup.addItems(withTitles: appearanceTitles)
        addRow("Appearance", appearancePopup)

        dialPopup = NSPopUpButton()
        dialPopup.addItems(withTitles: Palettes.dialNames)
        addRow("Dial", dialPopup)

        lumePopup = NSPopUpButton()
        lumePopup.addItems(withTitles: Palettes.lumeNames)
        addRow("Lume (night)", lumePopup)

        movementPopup = NSPopUpButton()
        movementPopup.addItems(withTitles: movementTitles)
        addRow("Movement", movementPopup)

        sizePopup = NSPopUpButton()
        sizePopup.addItems(withTitles: sizeTitles)
        addRow("Size", sizePopup)

        secondsCheck = NSButton(checkboxWithTitle: "Show second hand", target: nil, action: nil)
        secondsCheck.frame = NSRect(x: 114, y: y, width: 210, height: 22)
        content.addSubview(secondsCheck)

        // Buttons
        let ok = NSButton(title: "OK", target: self, action: #selector(okClicked))
        ok.bezelStyle = .rounded
        ok.keyEquivalent = "\r"
        ok.frame = NSRect(x: 232, y: 14, width: 92, height: 30)
        content.addSubview(ok)

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.frame = NSRect(x: 138, y: 14, width: 92, height: 30)
        content.addSubview(cancel)
    }

    // MARK: - Load / Save

    private func loadValues() {
        let appearance = defaults?.string(forKey: "appearance") ?? "night"
        if let i = appearanceValues.firstIndex(of: appearance) {
            appearancePopup.selectItem(at: i)
        }
        dialPopup.selectItem(withTitle: defaults?.string(forKey: "dial") ?? "Noir")
        lumePopup.selectItem(withTitle: defaults?.string(forKey: "lume") ?? "Tritium Green")
        movementPopup.selectItem(withTitle: defaults?.string(forKey: "movement") ?? "Mechanical")
        sizePopup.selectItem(withTitle: defaults?.string(forKey: "size") ?? "Classic")
        let seconds = defaults?.object(forKey: "seconds") != nil ? defaults!.bool(forKey: "seconds") : true
        secondsCheck.state = seconds ? .on : .off
    }

    @objc private func okClicked() {
        let appearance = appearanceValues[max(0, appearancePopup.indexOfSelectedItem)]
        defaults?.set(appearance, forKey: "appearance")
        defaults?.set(dialPopup.titleOfSelectedItem ?? "Noir", forKey: "dial")
        defaults?.set(lumePopup.titleOfSelectedItem ?? "Tritium Green", forKey: "lume")
        defaults?.set(movementPopup.titleOfSelectedItem ?? "Mechanical", forKey: "movement")
        defaults?.set(sizePopup.titleOfSelectedItem ?? "Classic", forKey: "size")
        defaults?.set(secondsCheck.state == .on, forKey: "seconds")
        defaults?.synchronize()

        // Tell the (separate) rendering process to refresh now.
        DistributedNotificationCenter.default().postNotificationName(
            Self.configChangedNotification, object: nil, userInfo: nil, deliverImmediately: true)

        dismiss()
    }

    @objc private func cancelClicked() {
        dismiss()
    }

    private func dismiss() {
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.close()
        }
    }
}
