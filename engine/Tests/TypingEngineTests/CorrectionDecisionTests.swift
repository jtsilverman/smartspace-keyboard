import Testing
import TypingEngine

/// Fake checker keyed on the lowercased word; suggestions stored lowercase,
/// like UITextChecker's typical output for common typos.
struct FakeChecker: SpellChecking {
    let misspellings: [String: [String]]

    func suggestions(for word: String) -> [String] {
        misspellings[word.lowercased()] ?? []
    }
}

let checker = FakeChecker(misspellings: [
    "teh": ["the", "ten", "tech"],
    "realy": ["really", "real"],
    "xiomara": ["xiomar"],
    "asap": ["asap's"],
])

@Test func misspelledWordIsCorrectedToTopSuggestionWithAlternatives() {
    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "hello teh") ==
        .correct(to: "the", alternatives: ["ten", "tech"]))
}

@Test func correctlySpelledWordIsLeftAlone() {
    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "hello there") == .noChange)
}

@Test func lexiconWordsAreNeverCorrectedAway() {
    let engine = CorrectionEngine(checker: checker, lexicon: ["Xiomara"])
    #expect(engine.decision(for: "hey xiomara") == .noChange)
    #expect(engine.decision(for: "hey Xiomara") == .noChange)
}

@Test func leadingCapitalIsReappliedToSuggestions() {
    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "Teh") ==
        .correct(to: "The", alternatives: ["Ten", "Tech"]))
}

@Test func suggestionsWithTheirOwnCapitalsKeepTheCheckerCasing() {
    let brandChecker = FakeChecker(misspellings: ["iphnoe": ["iPhone"]])
    let engine = CorrectionEngine(checker: brandChecker)
    #expect(engine.decision(for: "my Iphnoe") ==
        .correct(to: "iPhone", alternatives: []))
}

@Test func allCapsWordsAreNeverCorrected() {
    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "need it ASAP") == .noChange)
}

@Test func degenerateContextsDecideNoChange() {
    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "") == .noChange)
    #expect(engine.decision(for: "   ") == .noChange)
    #expect(engine.decision(for: "teh ") == .noChange)
    #expect(engine.decision(for: "room 4b") == .noChange)
}
