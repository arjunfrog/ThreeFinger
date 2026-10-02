import Testing
@testable import ThreeFinger

struct GestureRecognizerTests {
    private let frameInterval = 1.0 / 90

    /// Puts fingers down, slides them by (dx, dy) over `frames` frames, then lifts them.
    private func gesture(fingers: Int = 3, dx: Float = 0, dy: Float = 0, frames: Int = 20) -> [Gesture] {
        var recognizer = GestureRecognizer()
        var results: [Gesture] = []
        var time = 0.0
        for frame in 0...frames {
            let progress = Float(frame) / Float(frames)
            let touches = (0..<fingers).map {
                GestureRecognizer.Touch(id: Int32($0), x: 0.4 + Float($0) * 0.08 + dx * progress, y: 0.5 + dy * progress)
            }
            results += recognizer.process(touches, at: time)
            time += frameInterval
        }
        return results + recognizer.process([], at: time)
    }

    @Test func testQuickTapPlaysOrPauses() {
        #expect(gesture(frames: 10) == [.tap])
    }

    @Test func testLongPressIsNotATap() {
        #expect(gesture(frames: 60) == [])
    }

    @Test func testSwipeRightSkipsOnce() {
        #expect(gesture(dx: 0.4) == [.swipeRight])
    }

    @Test func testSwipeLeftGoesBackOnce() {
        #expect(gesture(dx: -0.4) == [.swipeLeft])
    }

    @Test func testLongerSwipeUpRaisesVolumeMore() {
        #expect(gesture(dy: 0.15) == [.swipeUp, .swipeUp])
        #expect(gesture(dy: 0.3) == [.swipeUp, .swipeUp, .swipeUp, .swipeUp])
    }

    @Test func testSwipeDownLowersVolume() {
        #expect(gesture(dy: -0.15) == [.swipeDown, .swipeDown])
    }

    @Test func testShortSlideDoesNothing() {
        #expect(gesture(dx: 0.08, frames: 60) == [])
    }

    @Test func testTwoAndFourFingersAreIgnored() {
        #expect(gesture(fingers: 2, frames: 10) == [])
        #expect(gesture(fingers: 2, dx: 0.4) == [])
        #expect(gesture(fingers: 4, frames: 10) == [])
        #expect(gesture(fingers: 4, dy: 0.4) == [])
    }

    @Test func testFingersLandingOneByOneStillTap() {
        var recognizer = GestureRecognizer()
        let all = (0..<3).map { GestureRecognizer.Touch(id: Int32($0), x: 0.4 + Float($0) * 0.08, y: 0.5) }
        var results: [Gesture] = []
        results += recognizer.process(Array(all.prefix(1)), at: 0)
        results += recognizer.process(Array(all.prefix(2)), at: 0.02)
        results += recognizer.process(all, at: 0.04)
        results += recognizer.process(all, at: 0.10)
        results += recognizer.process(Array(all.prefix(1)), at: 0.14)
        results += recognizer.process([], at: 0.16)
        #expect(results == [.tap])
    }
}
