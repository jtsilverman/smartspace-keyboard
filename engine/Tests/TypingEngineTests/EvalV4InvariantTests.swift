import Testing
@testable import TypingEngine

/// Invariants surfaced by the v4 blind eval dev misses (specs/keyboard-eval.md).
/// Each names a failure CLASS, never a single row.

// MARK: - Capitalization: every terminator form ends a sentence

@Suite struct CapTerminatorForms {
    /// The single-char ellipsis terminates like a period.
    @Test func unicodeEllipsisTerminates() {
        #expect(CapitalizationRule.shouldCapitalize(before: "maybe\u{2026} "))
    }

    /// Trailing emoji after a terminator don't hide the sentence boundary
    /// (iOS 6+ behavior: "ok. 👍 " capitalizes the next word).
    @Test func emojiAfterTerminatorStillCapitalizes() {
        #expect(CapitalizationRule.shouldCapitalize(before: "ok. 👍 "))
        #expect(CapitalizationRule.shouldCapitalize(before: "done! 🎉🎉 "))
    }

    /// Emoji with no terminator anywhere behind them is mid-sentence.
    @Test func emojiWithoutTerminatorDoesNot() {
        #expect(!CapitalizationRule.shouldCapitalize(before: "lunch 🍕 "))
    }

    /// The guards that must survive the change.
    @Test func abbreviationAndMidSentenceStayUnchanged() {
        #expect(!CapitalizationRule.shouldCapitalize(before: "see e.g. "))
        #expect(!CapitalizationRule.shouldCapitalize(before: "on my way "))
    }
}

// MARK: - Contractions: non-word bare forms all fix

@Suite struct ContractionClassCoverage {
    /// Class rule: an apostrophe-less contraction whose bare form is not a
    /// common modern English word gets fixed. One representative per shape.
    @Test(arguments: [
        ("itll", "it\u{2019}ll"), ("thatll", "that\u{2019}ll"),
        ("youll", "you\u{2019}ll"), ("theyll", "they\u{2019}ll"),
        ("youd", "you\u{2019}d"), ("theyd", "they\u{2019}d"),
        ("shouldve", "should\u{2019}ve"), ("wouldve", "would\u{2019}ve"),
        ("couldve", "could\u{2019}ve"), ("mustve", "must\u{2019}ve"),
        ("mustnt", "mustn\u{2019}t"), ("aint", "ain\u{2019}t"),
        ("yall", "y\u{2019}all"), ("maam", "ma\u{2019}am"),
        ("hows", "how\u{2019}s"), ("wheres", "where\u{2019}s"),
        ("whos", "who\u{2019}s"),
        // Bare forms that exist only as archaic/marginal words: stock iOS
        // fixes them and so do we.
        ("wont", "won\u{2019}t"), ("lets", "let\u{2019}s"),
    ])
    func nonWordBareFormsFix(typed: String, fixed: String) {
        #expect(ContractionRule.transform(typed) == fixed)
    }

    /// Common-word homographs stay untouched -- the misfire mangles
    /// intended text, the expensive failure.
    @Test(arguments: ["ill", "id", "well", "hell", "shell", "wed", "its",
                      "were", "shed", "sans"])
    func commonWordHomographsStay(word: String) {
        #expect(ContractionRule.transform(word) == nil)
    }
}
