import AppKit
import CMultitouch
import IOKit

/// Reads raw finger positions from every trackpad and turns them into gestures.
final class TouchListener {
    static let shared = TouchListener()

    /// Called on the main thread.
    var onGesture: ((Gesture) -> Void)?

    private let lock = NSLock()
    private var recognizers: [UInt: GestureRecognizer] = [:]
    private var notifyPort: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    private var pendingRestart: DispatchWorkItem?

    /// Returns false if the system multitouch framework couldn't be loaded.
    @discardableResult
    func start() -> Bool {
        if notifyPort == nil { watchDevices() }

        lock.lock()
        recognizers.removeAll()
        lock.unlock()

        return MTListenerStart { device, touches, count, timestamp in
            TouchListener.shared.receive(device: device, touches: touches, count: count, timestamp: timestamp)
        } >= 0
    }

    private func receive(device: UInt, touches: UnsafePointer<MTTouchPoint>?, count: Int32, timestamp: Double) {
        var points: [GestureRecognizer.Touch] = []
        if let touches, count > 0 {
            points = (0..<Int(count)).map {
                GestureRecognizer.Touch(id: touches[$0].identifier, x: touches[$0].x, y: touches[$0].y)
            }
        }

        ScrollBlocker.shared.setFingerCount(points.count)

        lock.lock()
        if recognizers[device] == nil {
            let height = MTListenerDeviceHeight(device)
            recognizers[device] = height > 0 ? GestureRecognizer(trackpadHeight: height) : GestureRecognizer()
        }
        let gestures = recognizers[device]!.process(points, at: timestamp)
        lock.unlock()

        for gesture in gestures {
            DispatchQueue.main.async { self.onGesture?(gesture) }
        }
    }

    // Trackpads stop sending touches after sleep, and a Magic Trackpad can connect at any time.
    // Either way the device list has to be rebuilt.
    private func watchDevices() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleRestart()
        }

        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        IONotificationPortSetDispatchQueue(port, .main)
        notifyPort = port

        let context = Unmanaged.passUnretained(self).toOpaque()
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let result = IOServiceAddMatchingNotification(
                port, type, IOServiceMatching("AppleMultitouchDevice"),
                { context, iterator in
                    TouchListener.drain(iterator)
                    Unmanaged<TouchListener>.fromOpaque(context!).takeUnretainedValue().scheduleRestart()
                },
                context, &iterator
            )
            guard result == KERN_SUCCESS else { continue }
            // Draining arms the notification. Devices already present are handled by start().
            Self.drain(iterator)
            iterators.append(iterator)
        }
    }

    private static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }

    private func scheduleRestart() {
        pendingRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.start() }
        pendingRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }
}
