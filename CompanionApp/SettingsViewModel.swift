import SwiftUI
import ScreenSaver

class SettingsViewModel: ObservableObject {
    private let defaults: UserDefaults

    @Published var appearance: String
    @Published var dial: String
    @Published var size: String
    @Published var movement: String
    @Published var lume: String
    @Published var seconds: Bool

    // Dial carousel scroll position
    @Published var dialScrollOffset: Int = 0

    init() {
        // Write to the SAME store the screensaver reads from. The .saver reads via
        // ScreenSaverDefaults(forModuleWithName: <saver bundle id>), which is a
        // distinct backing store from UserDefaults(suiteName:) even when the names
        // match — so we must use ScreenSaverDefaults here too, or OK never reaches
        // the screensaver.
        let moduleName = "com.bauhausclk.BauhausClock" // = saver's CFBundleIdentifier
        let d: UserDefaults = ScreenSaverDefaults(forModuleWithName: moduleName) ?? .standard
        d.register(defaults: [
            "appearance": "night",
            "dial": "Noir",
            "size": "Classic",
            "movement": "Mechanical",
            "lume": "Tritium Green",
            "seconds": true,
        ])
        self.defaults = d

        // Migrate from old boolean "night" key if "appearance" was never set
        if d.object(forKey: "appearance") == nil, d.object(forKey: "night") != nil {
            self.appearance = d.bool(forKey: "night") ? "night" : "day"
        } else {
            self.appearance = d.string(forKey: "appearance") ?? "night"
        }

        self.dial = d.string(forKey: "dial") ?? "Noir"
        self.size = d.string(forKey: "size") ?? "Classic"
        self.movement = d.string(forKey: "movement") ?? "Mechanical"
        self.lume = d.string(forKey: "lume") ?? "Tritium Green"
        self.seconds = d.object(forKey: "seconds") != nil ? d.bool(forKey: "seconds") : true

        // Center scroll on the selected dial
        if let idx = Palettes.dialNames.firstIndex(of: self.dial) {
            self.dialScrollOffset = max(0, min(idx - 2, Palettes.dialNames.count - 5))
        }
    }

    var movementDescription: String {
        switch movement {
        case "Quartz": return "Quartz tick"
        case "Digital": return "Smooth sweep"
        default: return "Mechanical sweep"
        }
    }

    func save() {
        defaults.set(appearance, forKey: "appearance")
        defaults.set(dial, forKey: "dial")
        defaults.set(size, forKey: "size")
        defaults.set(movement, forKey: "movement")
        defaults.set(lume, forKey: "lume")
        defaults.set(seconds, forKey: "seconds")
        defaults.synchronize()
    }
}
