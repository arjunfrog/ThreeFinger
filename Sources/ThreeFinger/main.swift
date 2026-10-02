import AppKit

MainActor.assumeIsolated {
    #if DEBUG
    if let index = CommandLine.arguments.firstIndex(of: "--snapshot") {
        Snapshot.write(toDirectory: CommandLine.arguments[index + 1])
        exit(0)
    }
    #endif

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
