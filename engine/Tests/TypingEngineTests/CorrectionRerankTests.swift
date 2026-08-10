import Testing
import TypingEngine

// MARK: - Guess re-rank: UITextChecker returns guesses alphabetically on
// iOS (nshipster.com/uitextchecker; ansonl/ios-uitextchecker-autocorrect),
// so the engine must re-rank by edit distance, then word frequency, before
// trusting the top guess.

/// Alphabetical guesses, the shape iOS hands back for "hte". Every guess is
/// one edit away; frequency alone must pick "the" over "hate".
private let alphabeticalChecker = FakeChecker(misspellings: [
    "hte": ["hate", "hie", "hoe", "hue", "the"],
    "helo": ["halo", "have", "hello"],
])

@Test func frequencyBreaksEditDistanceTies() {
    let engine = CorrectionEngine(checker: alphabeticalChecker)
    guard case .correct(let to, _) = engine.decision(for: "typed hte") else {
        Issue.record("expected a correction")
        return
    }
    #expect(to == "the")
}

@Test func closerEditBeatsHigherFrequency() {
    // "have" is far more frequent than "hello" but 3 edits away from
    // "helo"; distance dominates, then rank picks hello over halo.
    let engine = CorrectionEngine(checker: alphabeticalChecker)
    guard case .correct(let to, let alternatives) = engine.decision(for: "typed helo") else {
        Issue.record("expected a correction")
        return
    }
    #expect(to == "hello")
    #expect(alternatives == ["halo", "have"])
}
