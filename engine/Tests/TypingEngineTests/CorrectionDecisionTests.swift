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
        .correct(to: "the", alternatives: ["tech", "ten"]))
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
        .correct(to: "The", alternatives: ["Tech", "Ten"]))
}

// Sentence-start context: mid-sentence a capitalized unknown reads as a
// proper noun and is protected (v4 guard, CorrectionGuardClasses).
@Test func suggestionsWithTheirOwnCapitalsKeepTheCheckerCasing() {
    let brandChecker = FakeChecker(misspellings: ["iphnoe": ["iPhone"]])
    let engine = CorrectionEngine(checker: brandChecker)
    #expect(engine.decision(for: "Iphnoe") ==
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

// Spec smart-symbols-wire AC 1/2/2b: the contraction fix inside the
// correction pipeline (bar/undo/protection ride along for free).
@Test func contractionFixOutranksTheChecker() {
    let engine = CorrectionEngine(checker: FakeChecker(misspellings: ["dont": ["donut"]]))
    #expect(engine.decision(for: "i dont") ==
        .correct(to: "don\u{2019}t", alternatives: []))
}

@Test func standaloneLowercaseIIsCapitalized() {
    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "well i") == .correct(to: "I", alternatives: []))
}

@Test func contractionKeepsLeadingCapAndAllCapsOutranksAcronymGuard() {
    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "Dont") ==
        .correct(to: "Don\u{2019}t", alternatives: []))
    #expect(engine.decision(for: "DONT") ==
        .correct(to: "DON\u{2019}T", alternatives: []))
}

@Test func typedApostropheContractionStillRecased() {
    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "hey i'm") ==
        .correct(to: "I\u{2019}m", alternatives: []))
}

@Test func alreadyCorrectFormsAreLeftAlone() {
    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "sure I") == .noChange)
    #expect(engine.decision(for: "we don\u{2019}t") == .noChange)
}

@Test func protectionAndLexiconOutrankTheContractionFix() {
    var session = CorrectionSession()
    session.recordCorrection(original: "dont")
    _ = session.undoLast()
    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "ok dont", session: session) == .noChange)

    let lexiconEngine = CorrectionEngine(checker: checker, lexicon: ["dont"])
    #expect(lexiconEngine.decision(for: "ok dont") == .noChange)
}
