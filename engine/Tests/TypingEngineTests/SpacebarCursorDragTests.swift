import Testing
@testable import TypingEngine

// Spec keyboard-polish AC 1: drag distance -> cursor-step deltas, truncating
// toward zero, accumulating exactly, fresh per drag.
@Suite struct SpacebarCursorDragTests {
    @Test func oneStepRightEmitsPlusOne() {
        var drag = SpacebarCursorDrag()
        drag.began(at: 100)
        #expect(drag.moved(to: 100 + SpacebarCursorDrag.stepWidth) == 1)
    }

    @Test func subStepMovementEmitsZeroBothDirections() {
        var drag = SpacebarCursorDrag()
        drag.began(at: 100)
        #expect(drag.moved(to: 100 + SpacebarCursorDrag.stepWidth * 0.9) == 0)
        drag.began(at: 100)
        #expect(drag.moved(to: 100 - SpacebarCursorDrag.stepWidth * 0.9) == 0)
    }

    @Test func leftwardTravelEmitsNegative() {
        var drag = SpacebarCursorDrag()
        drag.began(at: 100)
        #expect(drag.moved(to: 100 - SpacebarCursorDrag.stepWidth * 2) == -2)
    }

    @Test func deltasAccumulateWithoutDoubleCounting() {
        var drag = SpacebarCursorDrag()
        drag.began(at: 0)
        let w = SpacebarCursorDrag.stepWidth
        #expect(drag.moved(to: w) == 1)
        #expect(drag.moved(to: w * 1.5) == 0)   // still within step 1
        #expect(drag.moved(to: w * 3) == 2)     // catches up to 3 total
        #expect(drag.moved(to: 0) == -3)        // back to origin
    }

    @Test func newDragStartsFresh() {
        var drag = SpacebarCursorDrag()
        drag.began(at: 0)
        _ = drag.moved(to: SpacebarCursorDrag.stepWidth * 4)
        drag.began(at: 500)
        #expect(drag.moved(to: 500 + SpacebarCursorDrag.stepWidth * 0.5) == 0)
        #expect(drag.moved(to: 500 + SpacebarCursorDrag.stepWidth) == 1)
    }

    // Property: at every point in a random move sequence, total emitted
    // matches an independent oracle. The oracle counts crossed step
    // thresholds by iteration (a different mechanism than the impl's
    // division), so a wrong rounding direction cannot cancel out.
    @Test func emittedTotalAlwaysMatchesThresholdCount() {
        func steps(for dx: Double, width: Double) -> Int {
            var k = 0
            if dx >= 0 {
                while Double(k + 1) * width <= dx { k += 1 }
                return k
            }
            while Double(k + 1) * width <= -dx { k += 1 }
            return -k
        }
        let w = SpacebarCursorDrag.stepWidth
        let x0 = 250.0
        var drag = SpacebarCursorDrag()
        drag.began(at: x0)
        var total = 0
        var x = x0
        // Deterministic pseudo-random walk (no seeded RNG in swift-testing).
        for i in 0..<200 {
            let step = Double((i * 37 % 23) - 11) * 1.7
            x += step
            total += drag.moved(to: x)
            #expect(total == steps(for: x - x0, width: w))
        }
    }
}
