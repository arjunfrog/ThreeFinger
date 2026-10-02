import Testing
@testable import ThreeFinger

struct ScrollFilterTests {
    // CGScrollPhase and CGMomentumScrollPhase values, as they appear in scroll event fields.
    private let mayBegin: Int64 = 128, began: Int64 = 1, changed: Int64 = 2, ended: Int64 = 4
    private let momentumBegin: Int64 = 1, momentumContinue: Int64 = 2, momentumEnd: Int64 = 3

    private struct Event {
        var phase: Int64 = 0
        var momentum: Int64 = 0
        var threeFingers = false
    }

    private func drops(_ events: [Event]) -> [Bool] {
        var filter = ScrollFilter()
        return events.map { filter.shouldDrop(phase: $0.phase, momentum: $0.momentum, threeFingersDown: $0.threeFingers) }
    }

    @Test func twoFingerScrollAlwaysPasses() {
        let scroll = [
            Event(phase: mayBegin), Event(phase: began), Event(phase: changed), Event(phase: ended),
            Event(momentum: momentumBegin), Event(momentum: momentumContinue), Event(momentum: momentumEnd),
        ]
        #expect(drops(scroll) == Array(repeating: false, count: scroll.count))
    }

    @Test func threeFingerSwipeAndItsMomentumAreDropped() {
        let swipe = [
            Event(phase: mayBegin),                        // fingers still landing
            Event(phase: began, threeFingers: true),
            Event(phase: changed, threeFingers: true),
            Event(phase: ended),                           // fingers already lifted
            Event(momentum: momentumBegin),
            Event(momentum: momentumContinue),
            Event(momentum: momentumEnd),
        ]
        #expect(drops(swipe) == [false, true, true, true, true, true, true])
    }

    @Test func nextScrollAfterSwipePasses() {
        let events = [
            Event(phase: changed, threeFingers: true),
            Event(momentum: momentumContinue),
            Event(phase: mayBegin),
            Event(phase: began),
            Event(phase: changed),
        ]
        #expect(drops(events) == [true, true, false, false, false])
    }

    @Test func liftingToTwoFingersMidSwipeStaysStill() {
        let events = [
            Event(phase: changed, threeFingers: true),
            Event(phase: changed),
            Event(phase: changed),
            Event(phase: ended),
        ]
        #expect(drops(events) == [true, true, true, true])
    }
}
