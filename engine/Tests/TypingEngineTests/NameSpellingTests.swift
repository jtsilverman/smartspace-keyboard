import Testing
@testable import TypingEngine

/// Vision milestone 5, the names half of specs/autocorrect-parity.md: "a name
/// the engine mangles is the most expensive miscorrection there is". Stock
/// left these spellings alone (oracle rows name-029, name-032, name-040),
/// because they are real names; the 2014 word list does not carry them, so
/// our engine reads them as typos of Jessica, Daniel and Nathan (EVAL.md,
/// "The names slice is a dictionary gap, not a rule gap").
@Suite struct NameSpellingTests {
    private let engine = CorrectionEngine(checker: DictionarySpellChecker())

    @Test func aRealNameSpellingIsNotATypo() {
        #expect(engine.decision(for: "ask jesica") == .noChange)
        #expect(engine.decision(for: "call danial") == .noChange)
        #expect(engine.decision(for: "nathen") == .noChange)
    }
}
