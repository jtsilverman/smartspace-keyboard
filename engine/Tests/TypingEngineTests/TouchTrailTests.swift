import Testing
@testable import TypingEngine

/// Vision milestone 5: "sloppy thumbs land on the word stock lands on".
/// Unit 2 of specs/autocorrect-parity.md hands the tap points to the
/// corrector. The probes measured stock recovering 100% of off-centre taps
/// that produced a wrong letter, and 47% of dead-centre ones, so where the
/// thumb sat has to reach the decision.
@Suite struct TouchTrailTests {
    private static let zones: [KeyZone] = StockLayoutMetrics
        .cells(width: 402, plane: KeyboardLayout.letterRows)
        .map { KeyZone(id: $0.id, frame: $0.frame) }

    private static func centre(_ letter: Character) -> Point {
        let zone = zones.first { $0.id == String(letter) }!
        return Point(x: zone.frame.x + zone.frame.width / 2,
                     y: zone.frame.y + zone.frame.height / 2)
    }

    /// A trail for `word`, every tap dead centre except `slot`, whose tap sits
    /// most of the way toward `toward`.
    private static func trail(for word: String, slot: Int, toward: Character,
                              fraction: Double) -> TouchTrail {
        var trail = TouchTrail(zones: zones)
        for (index, letter) in word.enumerated() {
            let from = centre(letter), to = centre(toward)
            let point = index == slot
                ? Point(x: from.x + (to.x - from.x) * fraction,
                        y: from.y + (to.y - from.y) * fraction)
                : from
            trail.record(point)
        }
        return trail
    }

    @Test func aTapThatNearlyLandedOnTheOtherKeyCorrectsToIt() {
        let engine = CorrectionEngine(checker: DictionarySpellChecker())
        // "mokey": the k tap sat 80% of the way toward n, so the thumb was
        // reaching for "money".
        let leaning = Self.trail(for: "mokey", slot: 2, toward: "n", fraction: 0.8)
        guard case .correct(let to, _) = engine.decision(for: "mokey", touches: leaning)
        else {
            Issue.record("no correction offered")
            return
        }
        #expect(to == "money")
    }

    @Test func aDeadCentreTapIsTakenAsTyped() {
        let engine = CorrectionEngine(checker: DictionarySpellChecker())
        let centred = Self.trail(for: "mokey", slot: 2, toward: "n", fraction: 0)
        #expect(engine.decision(for: "mokey", touches: centred) == .noChange)
    }
}
