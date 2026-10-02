import AppKit
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var isOn: Bool { didSet { defaults.set(isOn, forKey: "isOn"); updateScrollBlocking() } }
    @Published var playPause: Bool { didSet { defaults.set(playPause, forKey: "playPause") } }
    @Published var volume: Bool { didSet { defaults.set(volume, forKey: "volume"); updateScrollBlocking() } }
    @Published var tracks: Bool { didSet { defaults.set(tracks, forKey: "tracks"); updateScrollBlocking() } }
    @Published var showIcon: Bool { didSet { defaults.set(showIcon, forKey: "showIcon") } }

    @Published private(set) var lastGesture: Gesture?
    @Published private(set) var hasAccess = true
    @Published private(set) var conflicts: [TrackpadConflict] = []
    @Published private(set) var opensAtLogin = false
    @Published private(set) var trackpadUnavailable = false

    var needsAttention: Bool { trackpadUnavailable || !hasAccess || !conflicts.isEmpty }

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: ["isOn": true, "playPause": true, "volume": true, "tracks": true, "showIcon": true])
        isOn = defaults.bool(forKey: "isOn")
        playPause = defaults.bool(forKey: "playPause")
        volume = defaults.bool(forKey: "volume")
        tracks = defaults.bool(forKey: "tracks")
        showIcon = defaults.bool(forKey: "showIcon")
    }

    func start() {
        TouchListener.shared.onGesture = { [weak self] in self?.perform($0) }
        trackpadUnavailable = !TouchListener.shared.start()
        updateScrollBlocking()
        refreshStatus()
    }

    // A tap doesn't scroll, so only the swipes need the screen held still.
    private func updateScrollBlocking() {
        ScrollBlocker.shared.setEnabled(isOn && (volume || tracks))
    }

    func refreshStatus() {
        #if DEBUG
        if isPreview { return }
        #endif
        // Pressing media keys needs PostEvent and blocking scrolls needs Accessibility.
        // System Settings grants both with the one ThreeFinger switch under Accessibility.
        hasAccess = CGPreflightPostEventAccess() && AXIsProcessTrusted()
        if hasAccess {
            ScrollBlocker.shared.start()
        }
        conflicts = TrackpadConflict.current()
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    func perform(_ gesture: Gesture) {
        guard isOn else { return }
        switch gesture {
        case .tap:
            guard playPause else { return }
            MediaKey.playPause.press()
        case .volume(let steps):
            guard volume else { return }
            let key: MediaKey = steps > 0 ? .volumeUp : .volumeDown
            for _ in 0..<abs(steps) {
                key.press(quarterStep: true)
            }
        case .swipeLeft, .swipeRight:
            guard tracks else { return }
            (gesture == .swipeRight ? MediaKey.next : .previous).press()
        }
        lastGesture = gesture
    }

    func setOpensAtLogin(_ on: Bool) {
        let service = SMAppService.mainApp
        do {
            if on {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            NSLog("ThreeFinger: couldn't change login item: \(error)")
        }
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        opensAtLogin = service.status == .enabled
    }

    /// Adds ThreeFinger to the Accessibility list, where it can be switched on.
    func requestKeyAccess() {
        CGRequestPostEventAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    #if DEBUG
    private var isPreview = false

    func preview(hasAccess: Bool, conflicts: [TrackpadConflict], lastGesture: Gesture?) {
        self.hasAccess = hasAccess
        self.conflicts = conflicts
        self.lastGesture = lastGesture
        isPreview = true
    }
    #endif
}
