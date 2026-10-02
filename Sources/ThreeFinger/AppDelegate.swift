import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model = AppModel.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var observers: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        if handOffToRunningCopy() { return }

        model.start()
        setUpStatusItem()

        // Permissions and trackpad settings change in System Settings, which doesn't tell other apps.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in AppModel.shared.refreshStatus() }
        }

        if !launchedAtLogin || !model.canSendKeys || model.trackpadUnavailable {
            showPanel()
        }
        // macOS only shows this prompt if it hasn't asked before.
        if !model.canSendKeys {
            CGRequestPostEventAccess()
        }
    }

    // Opening the app from Finder or Spotlight while it's running drops the panel down,
    // which is the way in when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }

    private func setUpStatusItem() {
        statusItem.autosaveName = "ThreeFinger"
        statusItem.button?.image = NSImage(systemSymbolName: "hand.tap", accessibilityDescription: "ThreeFinger")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)

        popover.behavior = .transient
        popover.delegate = self
        let controller = NSHostingController(rootView: SettingsView(model: model))
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller

        // Hiding waits until the panel closes, so it doesn't vanish from under the pointer.
        model.$showIcon
            .sink { [weak self] showIcon in
                guard let self, !popover.isShown else { return }
                statusItem.isVisible = showIcon
            }
            .store(in: &observers)
        model.$isOn
            .sink { [weak self] in self?.statusItem.button?.appearsDisabled = !$0 }
            .store(in: &observers)
    }

    @objc private func togglePanel() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPanel()
        }
    }

    /// Shows the panel under the icon, putting the icon back for as long as the panel is open.
    private func showPanel() {
        let wasHidden = !statusItem.isVisible
        statusItem.isVisible = true
        model.refreshStatus()
        NSApp.activate(ignoringOtherApps: true)

        // A newly shown icon needs a moment to get its place in the menu bar.
        DispatchQueue.main.asyncAfter(deadline: .now() + (wasHidden ? 0.3 : 0)) { [self] in
            guard let button = statusItem.button, !popover.isShown else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeFirstResponder(nil)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.isVisible = model.showIcon
    }

    private var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    /// Only one copy should read the trackpad. A second one (say, opened from the build folder)
    /// asks the running copy to show its panel and quits.
    private func handOffToRunningCopy() -> Bool {
        guard let id = Bundle.main.bundleIdentifier,
              let other = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0 != .current }),
              let url = other.bundleURL else { return false }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        NSApp.terminate(nil)
        return true
    }
}
