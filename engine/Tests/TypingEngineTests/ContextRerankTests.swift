import Testing
@testable import TypingEngine

/// Unit 4a of specs/autocorrect-parity.md, vision milestone 5: "the same
/// typo corrects two ways in two different sentences". The preceding word
/// decides between candidates that sit the same edit distance away.
@Suite struct ContextRerankTests {
    private let engine = CorrectionEngine(checker: DictionarySpellChecker())

    private func corrected(_ context: String) -> String? {
        if case .correct(let to, _) = engine.decision(for: context) { return to }
        return nil
    }

    /// "then" and "than" are both one substitution from "thn". Norvig's
    /// bigram counts (eval source, count_2w.txt) put "more than" at 126.5M
    /// against "more then" at 1.4M, and "and then" at 65.6M against "and
    /// than" at 0.2M, so the word before the typo picks a different winner
    /// in each sentence.
    @Test func sameTypoCorrectsTwoWaysByPrecedingWord() {
        #expect(corrected("more thn") == "than")
        #expect(corrected("and thn") == "then")
    }
}
