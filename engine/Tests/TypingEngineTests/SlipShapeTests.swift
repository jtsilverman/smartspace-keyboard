import Testing
@testable import TypingEngine

/// Two slip shapes the stock keyboard leaves alone, read off the recorded
/// slips slice (eval/oracle/stock-2026-09-12.tsv), vision milestone 5.
@Suite struct SlipShapeTests {
    private let engine = CorrectionEngine(checker: DictionarySpellChecker())

    private func run(_ typed: String) -> String {
        var controller = AutocorrectController(checker: DictionarySpellChecker())
        var field = ""
        for word in typed.split(separator: " ", omittingEmptySubsequences: true) {
            field += (field.isEmpty ? "" : " ") + word
            if case .replace(let original, let corrected, _) = controller.wordCommitted(context: field) {
                field = String(field.dropLast(original.count)) + corrected
            }
        }
        return field
    }

    /// Stock left "t ournament", "c harity" and "pa rticularly" as typed
    /// (slip-048594, slip-149822, slip-024746). The join refuses a one-letter
    /// fragment on purpose, and the single-word path then re-added the
    /// fragment to the second token ("t tournament"), a join in disguise.
    @Test func aCorrectionThatReaddsTheFragmentBeforeItStaysAsTyped() {
        #expect(run("t ournament") == "t ournament")
        #expect(run("c harity") == "c harity")
        #expect(run("pa rticularly") == "pa rticularly")
    }

    /// The trade the re-add rule makes, pinned: "a lready" has "ready" one
    /// edit away, and it still stays as typed, because the recorded rows say
    /// stock leaves a fragment pair whole rather than fixing its second half.
    @Test func theReaddRuleLeavesTheWholeWordEvenWhenAnotherFixExists() {
        #expect(run("a lready") == "a lready")
    }

    /// Stock left "orthern" and "illages" without their first letter and
    /// turned "eavy" into "wavy", never "heavy" (slip-024454, slip-071878,
    /// slip-034784): a candidate that only prepends a letter is not a fix,
    /// and the next candidate, if any survives, is.
    @Test func aDroppedFirstLetterStaysDropped() {
        #expect(engine.decision(for: "orthern") == .noChange)
        #expect(engine.decision(for: "illages") == .noChange)
        guard case .correct(let to, _) = engine.decision(for: "so eavy") else {
            Issue.record("eavy was left alone"); return
        }
        #expect(to == "wavy")
    }
}
