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

    /// Stock reads "onmy" as "on my" over "only" and "melater" as "me later"
    /// over "melter" (oracle rows nosp-001 and nosp-005). Unit 4a: a split
    /// whose halves are a known word pair outranks a word one edit away. The
    /// word-pair table is what tells "on my" from "din net", which scoring
    /// every split below a substitution could not; that cost 8 points of the
    /// typo bench.
    @Test func aPairBackedSplitOutranksANearSingleWord() {
        guard case .correct(let onmy, _) = engine.decision(for: "im onmy"),
              case .correct(let melater, _) = engine.decision(for: "call melater") else {
            Issue.record("no correction offered")
            return
        }
        #expect(onmy == "on my")
        #expect(melater == "me later")
    }

    @Test func bothHalvesMustBeCommon() {
        // Stock refused "amin" rather than offer "am in" (EVAL.md); "amin" is
        // not a word and neither half clears the frequency floor together.
        guard case .correct(let to, _) = engine.decision(for: "i amin") else { return }
        #expect(to != "am in")
    }
}
