import Testing
@testable import TypingEngine

/// Vision milestone 5: "sloppy thumbs land on the word stock lands on".
/// Unit 1 of specs/autocorrect-parity.md makes our own dictionary the
/// candidate source, so a common typo must reach its intended word with no
/// UITextChecker in the path.
@Suite struct DictionarySpellCheckerTests {
    @Test func commonTypoReachesItsIntendedWord() {
        let suggestions = DictionarySpellChecker().suggestions(for: "teh")
        #expect(suggestions.contains("the"))
    }
}

/// Vision milestone 5: "a message typed with the spaces missing comes back as
/// words". Unit 3 of specs/autocorrect-parity.md. `UITextChecker` could not
/// propose two words for one token at all, so this was impossible before the
/// dictionary replaced it.
@Suite struct MissedSpaceTests {
    private let engine = CorrectionEngine(checker: DictionarySpellChecker())

    @Test func aRunTogetherTokenComesBackAsTwoWords() {
        guard case .correct(let to, _) = engine.decision(for: "thankyou") else {
            Issue.record("no correction offered")
            return
        }
        #expect(to == "thank you")
    }

    /// Stock reads "onmy" as "on my" over "only". Ours picks "only" until the
    /// word-pair model of unit 4a can tell "on my" from "din net"; scoring
    /// splits below substitutions without it cost 8 points of the typo bench.
    @Test func aSplitLosesToANearSingleWordForNow() {
        guard case .correct(let to, _) = engine.decision(for: "im onmy") else { return }
        #expect(to == "only")
    }

    @Test func bothHalvesMustBeCommon() {
        // Stock refused "amin" rather than offer "am in" (EVAL.md); "amin" is
        // not a word and neither half clears the frequency floor together.
        guard case .correct(let to, _) = engine.decision(for: "i amin") else { return }
        #expect(to != "am in")
    }
}
