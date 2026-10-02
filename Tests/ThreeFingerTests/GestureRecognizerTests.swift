import Testing
@testable import ThreeFinger

struct GestureRecognizerTests {
    private let frameInterval = 1.0 / 90

    /// Puts fingers down, slides them by (dx, dy) over `frames` frames, then lifts them.
    private func gesture(
        fingers: Int = 3, dx: Float = 0, dy: Float = 0, frames: Int = 20, trackpadHeight: Float = 75
    ) -> [Gesture] {
        var recognizer = GestureRecognizer(trackpadHeight: trackpadHeight)
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

    /// Net quarter volume steps from a gesture.
    private func volumeSteps(_ gestures: [Gesture]) -> Int {
        gestures.reduce(0) { total, gesture in
            if case .volume(let steps) = gesture { total + steps } else { total }
        }
    }

    @Test func testSwipeUpRaisesVolumeAndDownLowersIt() {
        #expect(volumeSteps(gesture(dy: 0.3)) > 0)
        #expect(volumeSteps(gesture(dy: -0.3)) < 0)
        #expect(!gesture(dy: 0.3).contains(.tap))
    }

    /// Normalized distance on the default 75 mm trackpad.
    private func millimetres(_ mm: Float) -> Float { mm / 75 }

    @Test func testEachTwoAndAHalfMillimetresIsOneNotch() {
        // A notch is four quarter steps. Under 3 mm isn't a swipe yet, so a tap can wobble.
        #expect(volumeSteps(gesture(dy: millimetres(2.6))) == 0)
        #expect(volumeSteps(gesture(dy: millimetres(5.1))) == 8)
        #expect(volumeSteps(gesture(dy: millimetres(10.2))) == 16)
        #expect(volumeSteps(gesture(dy: millimetres(-5.1))) == -8)
    }

    @Test func testSpeedDoesNotChangeTheAmount() {
        #expect(volumeSteps(gesture(dy: millimetres(10.2), frames: 180)) == 16)
        #expect(volumeSteps(gesture(dy: millimetres(10.2), frames: 10)) == 16)
    }

    @Test func testDistancesAreRealOnABiggerTrackpad() {
        // The same 10 mm is a smaller share of a 150 mm trackpad's height.
        #expect(volumeSteps(gesture(dy: 10.2 / 150, trackpadHeight: 150)) == 16)
    }

    @Test func testVolumeGlidesInQuarterSteps() {
        // The first change catches up the movement made before the swipe was known to be vertical.
        let gestures = gesture(dy: millimetres(10.2), frames: 80).dropFirst()
        #expect(gestures.count > 8)
        #expect(gestures.allSatisfy { $0 == .volume(steps: 1) })
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
