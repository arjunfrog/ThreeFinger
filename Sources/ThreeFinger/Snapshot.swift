#if DEBUG
import AppKit
import SwiftUI

/// Renders the menu bar panel to PNGs for checking the layout: `swift run ThreeFinger --snapshot <dir>`.
@MainActor
enum Snapshot {
    static func write(toDirectory directory: String) {
        _ = NSApplication.shared
        let states: [(String, Bool, [TrackpadConflict], Gesture?)] = [
            ("clean", true, [], nil),
            ("issues", false, [.threeFingerDrag, .missionControl], .swipeLeft),
        ]
        for (name, hasAccess, conflicts, gesture) in states {
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                let model = AppModel()
                model.preview(hasAccess: hasAccess, conflicts: conflicts, lastGesture: gesture)
                let suffix = appearance == .aqua ? "light" : "dark"
                render(SettingsView(model: model), appearance: appearance, to: "\(directory)/\(name)-\(suffix).png")
            }
        }
    }

    private static func render(_ view: some View, appearance: NSAppearance.Name, to path: String) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize

        // Approximates the menu material the real panel sits on.
        let background = NSVisualEffectView(frame: hosting.frame)
        background.material = .menu
        background.blendingMode = .withinWindow
        background.state = .active
        background.addSubview(hosting)

        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = background
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        guard let rep = background.bitmapImageRepForCachingDisplay(in: background.bounds) else { return }
        background.cacheDisplay(in: background.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        window.close()
    }
}
#endif
