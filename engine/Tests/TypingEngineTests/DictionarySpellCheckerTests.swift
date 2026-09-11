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

    @Test func aKnownWordIsNeverSplit() {
        // Stock refused "amin" rather than offer "am in" (EVAL.md). "am in" is
        // a strong pair; what stops the split is that Amin is a name the word
        // list holds, so the checker offers nothing for it.
        #expect(engine.decision(for: "i amin") == .noChange)
    }

    /// Protection row A063. "Kai" is a name in the list, and the capital on
    /// "Kaius" is autocap at a sentence start, so the split guard is the only
    /// thing between the token and "Kai us".
    @Test func aSplitNeverMakesAProperNoun() {
        #expect(engine.decision(for: "Kaius") == .noChange)
    }

    /// Protection row A184. "bad" and "ass" are both common, the word list
    /// does not hold "badass", and "bad ass" sits below the pair table's
    /// floor, so two short halves that are not a pair stay one token.
    @Test func twoShortHalvesSplitOnlyAsAPair() {
        #expect(engine.decision(for: "thats badass") == .noChange)
    }
}
