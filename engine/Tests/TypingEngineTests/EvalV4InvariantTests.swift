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

// MARK: - Smart symbols: dashes and primes serve the text they sit in

@Suite struct SymbolContextClasses {
    /// -- collapses to an em dash only between words (so--anyway); after a
    /// space it's CLI-flag territory (npm install --save-dev) and after
    /// another hyphen it's a divider (---). Class rule: collapse requires a
    /// word character immediately before the double hyphen.
    @Test func doubleHyphenCollapsesOnlyAfterWordCharOrTextStart() {
        #expect(SmartSymbols.decision(forTyping: "-", before: "so-")
                == .replacePrevious(with: "\u{2014}"))
        #expect(SmartSymbols.decision(forTyping: "-", before: "npm install -")
                == .insert("-"))
        #expect(SmartSymbols.decision(forTyping: "-", before: "--")
                == .insert("-"))
        // Message-start aside: --and another thing. (Zero-sum vs a literal
        // "---" divider typed at text start; the aside is the texting-real
        // pattern, adjudicated on the v4 dev set.)
        #expect(SmartSymbols.decision(forTyping: "-", before: "-")
                == .replacePrevious(with: "\u{2014}"))
    }

    /// A quote right after a digit is a prime (5'10", 6', 9mm vs 9") and
    /// stays straight -- unless an opening double quote is pending, where
    /// closing wins ("i'm 25").
    @Test func digitAdjacentQuotesStayStraight() {
        #expect(SmartSymbols.decision(forTyping: "'", before: "5") == .insert("'"))
        #expect(SmartSymbols.decision(forTyping: "\"", before: "5'10") == .insert("\""))
        #expect(SmartSymbols.decision(forTyping: "\"", before: "she said \u{201C}i\u{2019}m 25")
                == .insert("\u{201D}"))
    }

    /// Typing the third dot of ... collapses to a single-char ellipsis;
    /// two dots (ranges, 1..10) and version strings never trigger it.
    @Test func threeDotsCollapseToEllipsis() {
        #expect(SmartSymbols.decision(forTyping: ".", before: "wait..")
                == .replaceLast(2, with: "\u{2026}"))
        #expect(SmartSymbols.decision(forTyping: ".", before: "wait.")
                == .insert("."))
        #expect(SmartSymbols.decision(forTyping: ".", before: "1.2")
                == .insert("."))
        // A fourth dot after the collapse starts a fresh count, and dots
        // after an existing ellipsis char don't chain-collapse.
        #expect(SmartSymbols.decision(forTyping: ".", before: "wait\u{2026}")
                == .insert("."))
    }
}
