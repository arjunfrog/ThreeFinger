import Foundation

/// macOS trackpad settings that also use three fingers and would fire alongside these gestures.
enum TrackpadConflict: CaseIterable, Identifiable {
    case threeFingerDrag, missionControl, fullScreenApps, pages, lookUp

    var id: Self { self }

    var title: String {
        switch self {
        case .threeFingerDrag: "Three-finger drag is on"
        case .missionControl: "Mission Control uses three fingers"
        case .fullScreenApps: "Swipe between full-screen apps uses three fingers"
        case .pages: "Swipe between pages uses three fingers"
        case .lookUp: "Look up uses a three-finger tap"
        }
    }

    var fix: String {
        switch self {
        case .threeFingerDrag: "Swipes will also drag windows and select text. Turn it off in Accessibility > Pointer Control > Trackpad Options."
        case .missionControl, .fullScreenApps: "Change it to four fingers in Trackpad > More Gestures."
        case .pages: "Change it to two fingers in Trackpad > More Gestures."
        case .lookUp: "Change it to Force Click in Trackpad > Point & Click."
        }
    }

    var settingsURL: URL {
        switch self {
        case .threeFingerDrag: URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension")!
        default: URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!
        }
    }

    static func current() -> [TrackpadConflict] {
        domains.forEach { CFPreferencesAppSynchronize($0 as CFString) }
        return allCases.filter(\.isActive)
    }

    // Defaults are what a new Mac ships with when the key has never been written.
    private var isActive: Bool {
        switch self {
        case .threeFingerDrag: Self.anyValue("TrackpadThreeFingerDrag", default: 0) { $0 != 0 }
        case .missionControl: Self.anyValue("TrackpadThreeFingerVertSwipeGesture", default: 2) { $0 != 0 }
        case .fullScreenApps: Self.anyValue("TrackpadThreeFingerHorizSwipeGesture", default: 2) { $0 == 2 }
        case .pages: Self.anyValue("TrackpadThreeFingerHorizSwipeGesture", default: 2) { $0 == 1 }
        case .lookUp: Self.anyValue("TrackpadThreeFingerTapGesture", default: 0) { $0 != 0 }
        }
    }

    // The built-in trackpad and the Magic Trackpad keep separate copies of these settings.
    private static let domains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]

    private static func anyValue(_ key: String, default fallback: Int, where matches: (Int) -> Bool) -> Bool {
        let values = domains.compactMap { CFPreferencesCopyAppValue(key as CFString, $0 as CFString) as? Int }
        return (values.isEmpty ? [fallback] : values).contains(where: matches)
    }
}
