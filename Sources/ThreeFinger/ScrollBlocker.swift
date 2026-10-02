import CoreGraphics
import Foundation

/// Decides which trackpad scroll events to drop. When macOS has nothing assigned to three
/// fingers it treats them as a scroll, so a volume or track swipe would also move the page.
struct ScrollFilter {
    private static let began = Int64(CGScrollPhase.began.rawValue)
    private static let mayBegin = Int64(CGScrollPhase.mayBegin.rawValue)

    private var dropping = false

    /// `phase` and `momentum` are the event's scroll phase and momentum phase fields.
    mutating func shouldDrop(phase: Int64, momentum: Int64, threeFingersDown: Bool) -> Bool {
        if threeFingersDown {
            dropping = true
        } else if dropping, momentum == 0, phase == Self.began || phase == Self.mayBegin {
            // A fresh scroll. The swipe's last events and its momentum all arrive before this.
            dropping = false
        }
        return dropping
    }
}

/// Drops the scrolling macOS adds to three-finger swipes. Needs Accessibility access.
final class ScrollBlocker {
    static let shared = ScrollBlocker()

    private let lock = NSLock()
    private var threeFingersDown = false
    private var isEnabled = true
    private var filter = ScrollFilter() // Only touched on the tap's thread.
    private var tap: CFMachPort?

    /// Called from the trackpad thread on every frame.
    func setFingerCount(_ count: Int) {
        lock.lock()
        threeFingersDown = count == 3
        lock.unlock()
    }

    func setEnabled(_ enabled: Bool) {
        lock.lock()
        isEnabled = enabled
        lock.unlock()
    }

    /// Starts filtering scroll events. Returns false until ThreeFinger has Accessibility access.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1) << CGEventType.scrollWheel.rawValue,
            callback: { _, type, event, _ in ScrollBlocker.shared.handle(type, event) },
            userInfo: nil
        ) else { return false }
        self.tap = tap

        // Its own thread, so scrolling never waits on the main thread.
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "ThreeFinger scroll blocker"
        thread.qualityOfService = .userInteractive
        thread.start()
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS switches a tap off if it's ever too slow to answer. Switch it straight back on.
        if type == .tapDisabledByTimeout, let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        // Trackpad scrolling is continuous. Mouse wheels aren't, and are left alone.
        guard type == .scrollWheel, event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 else {
            return Unmanaged.passUnretained(event)
        }

        lock.lock()
        let blocking = isEnabled && threeFingersDown
        lock.unlock()

        let drop = filter.shouldDrop(
            phase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
            momentum: event.getIntegerValueField(.scrollWheelEventMomentumPhase),
            threeFingersDown: blocking
        )
        return drop ? nil : Unmanaged.passUnretained(event)
    }
}
