enum Gesture: Equatable {
    case tap, swipeLeft, swipeRight
    /// Quarter volume steps (1/64 of the range). Positive is up.
    case volume(steps: Int)

    var name: String {
        switch self {
        case .tap: "Tap"
        case .swipeLeft: "Swipe left"
        case .swipeRight: "Swipe right"
        case .volume(let steps): steps > 0 ? "Swipe up" : "Swipe down"
        }
    }
}

/// Turns frames of raw touches from one trackpad into three-finger gestures.
/// Positions are normalized to 0...1 with the origin at the bottom-left of the trackpad.
struct GestureRecognizer {
    struct Touch {
        var id: Int32
        var x: Float
        var y: Float
    }

    // A tap is three fingers down and up again quickly, without sliding.
    static let tapMaxDuration = 0.35
    static let tapMaxTravel: Float = 0.04
    // How far the fingers move before a swipe picks horizontal or vertical.
    static let axisLockDistance: Float = 0.04
    // Left and right fire once per swipe.
    static let trackSwipeDistance: Float = 0.12

    // Volume follows the fingers: one notch of the 16 in the volume overlay per 2.5 mm,
    // sent as quarter steps so it glides instead of jumping.
    static let notchDistance: Float = 2.5 // millimetres
    static let stepsPerNotch: Float = 4

    /// Height of the touch surface in millimetres, so distances are real on any trackpad.
    /// The default is roughly a MacBook trackpad, for when the device doesn't report its size.
    private let trackpadHeight: Float

    init(trackpadHeight: Float = 75) {
        self.trackpadHeight = trackpadHeight
    }

    private enum Axis { case horizontal, vertical }

    private var touchStart: Double?
    private var maxFingers = 0
    private var origins: [Int32: SIMD2<Float>] = [:]
    private var maxTravel: Float = 0
    private var anchor: SIMD2<Float>?
    private var anchorIDs: Set<Int32> = []
    private var axis: Axis?
    private var didSwipe = false
    private var lastCenter: SIMD2<Float>?
    private var volumeRemainder: Float = 0

    mutating func process(_ touches: [Touch], at time: Double) -> [Gesture] {
        guard !touches.isEmpty else {
            let isTap = maxFingers == 3 && !didSwipe && maxTravel <= Self.tapMaxTravel
                && time - (touchStart ?? time) <= Self.tapMaxDuration
            self = GestureRecognizer(trackpadHeight: trackpadHeight)
            return isTap ? [.tap] : []
        }

        if touchStart == nil { touchStart = time }
        maxFingers = max(maxFingers, touches.count)

        for touch in touches {
            let point = SIMD2(touch.x, touch.y)
            if let origin = origins[touch.id] {
                let d = point - origin
                maxTravel = max(maxTravel, (d * d).sum().squareRoot())
            } else {
                origins[touch.id] = point
            }
        }

        // A fourth finger cancels the gesture, so macOS's four-finger gestures don't also trigger one.
        guard maxFingers == 3, touches.count == 3 else { return [] }

        let ids = Set(touches.map(\.id))
        let center = touches.reduce(SIMD2<Float>()) { $0 + SIMD2($1.x, $1.y) } / 3
        guard let anchor, ids == anchorIDs else {
            self.anchor = center
            anchorIDs = ids
            lastCenter = nil
            return []
        }

        let delta = center - anchor
        if axis == nil {
            guard max(abs(delta.x), abs(delta.y)) >= Self.axisLockDistance else { return [] }
            axis = abs(delta.x) > abs(delta.y) ? .horizontal : .vertical
        }

        switch axis! {
        case .horizontal:
            guard !didSwipe, abs(delta.x) >= Self.trackSwipeDistance else { return [] }
            didSwipe = true
            return [delta.x > 0 ? .swipeRight : .swipeLeft]
        case .vertical:
            didSwipe = true
            // On the frame the axis locks, this counts all the movement since the fingers settled.
            let dy = center.y - (lastCenter ?? anchor).y
            lastCenter = center
            volumeRemainder += dy * trackpadHeight / Self.notchDistance * Self.stepsPerNotch
            let steps = Int(volumeRemainder)
            guard steps != 0 else { return [] }
            volumeRemainder -= Float(steps)
            return [.volume(steps: steps)]
        }
    }
}
