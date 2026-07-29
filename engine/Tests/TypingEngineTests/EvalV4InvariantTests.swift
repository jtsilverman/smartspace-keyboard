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

// MARK: - Autocorrect guards: never touch deliberate text

private struct CannedChecker: SpellChecking {
    let canned: [String: [String]]
    func suggestions(for word: String) -> [String] { canned[word.lowercased()] ?? [] }
}

@Suite struct CorrectionGuardClasses {
    private let engine = CorrectionEngine(checker: CannedChecker(canned: [
        "sooo": ["so"], "plsss": ["plus's"], "duuude": ["dude"],
        "gn": ["gun"], "rn": ["run"],
        "nkechi": ["Knit"], "shein": ["She-in"], "pinkydoll": ["pinky-doll"],
        "nofilter": ["no-filter"], "teh": ["the"], "wrod": ["word"],
    ]))

    /// Letter runs of 3+ are deliberate elongation (sooo, plsss, duuude),
    /// never typos; the checker's suggestions for them are garbage anyway.
    @Test(arguments: ["sooo", "plsss", "duuude"])
    func elongationsStay(word: String) {
        #expect(engine.decision(for: "omg \(word)") == .noChange)
    }

    /// Two-letter tokens are shortforms (gn, rn, ty, np); correcting them
    /// mangles texting vocabulary.
    @Test(arguments: ["gn", "rn"])
    func twoLetterTokensStay(word: String) {
        #expect(engine.decision(for: "ok \(word)") == .noChange)
    }

    /// A capitalized word mid-sentence is a proper noun (names, brands);
    /// at a sentence start the capital is just autocap and typos still fix.
    @Test func capitalizedMidSentenceIsAProperNoun() {
        #expect(engine.decision(for: "text Nkechi") == .noChange)
        #expect(engine.decision(for: "order it on Shein") == .noChange)
        #expect(engine.decision(for: "Teh") ==
                .correct(to: "The", alternatives: []))
    }

    /// The proper-noun read also outranks a contraction fix mid-sentence
    /// (Professor Cant is a surname, not can't).
    @Test func capitalizedMidSentenceContractionStays() {
        #expect(engine.decision(for: "Professor Cant") == .noChange)
        #expect(engine.decision(for: "Dont") ==
                .correct(to: "Don\u{2019}t", alternatives: []))
    }

    /// Handles and hashtags are addresses, not words.
    @Test func handleAndHashtagTokensStay() {
        #expect(WordBoundary.lastWord(in: "follow @pinkydoll_") == nil)
        #expect(WordBoundary.lastWord(in: "tag it #nofilter") == nil)
    }

    /// Control: plain lowercase typos mid-sentence still correct.
    @Test func plainTyposStillCorrect() {
        #expect(engine.decision(for: "read teh") ==
                .correct(to: "the", alternatives: []))
    }
}

@Suite struct TextingLexiconProtection {
    /// Distance-1 checker guesses at modern vocabulary (sus->sis, imy->my)
    /// can only be stopped by knowing the words; the shipped texting
    /// lexicon is default-on in the engine.
    @Test func shippedLexiconBlocksVocabularyGuesses() {
        let engine = CorrectionEngine(checker: CannedChecker(canned: [
            "sus": ["sis"], "imy": ["my"], "chisme": ["chime"],
            "danke": ["dance"], "rizz": ["ritz"],
        ]))
        for word in ["sus", "imy", "chisme", "danke", "rizz"] {
            #expect(engine.decision(for: word) == .noChange, "word: \(word)")
        }
    }

    /// The caller's UILexicon still unions on top.
    @Test func callerLexiconStillApplies() {
        let engine = CorrectionEngine(
            checker: CannedChecker(canned: ["jsilv": ["silva"]]),
            lexicon: ["jsilv"])
        #expect(engine.decision(for: "jsilv") == .noChange)
    }
}

@Suite struct SentenceStartIContractions {
    private let engine = CorrectionEngine(checker: CannedChecker(canned: [:]))

    /// "Ill"/"Id" at a sentence start are autocap products of the typed
    /// contraction (ill be there -> Ill -> I'll); mid-sentence and
    /// lowercase forms keep the homograph protection.
    @Test func autocappedIContractionsFixAtSentenceStart() {
        #expect(engine.decision(for: "Ill") ==
                .correct(to: "I\u{2019}ll", alternatives: []))
        #expect(engine.decision(for: "Id") ==
                .correct(to: "I\u{2019}d", alternatives: []))
    }

    @Test func homographProtectionSurvives() {
        #expect(engine.decision(for: "feel ill") == .noChange)
        #expect(engine.decision(for: "my id") == .noChange)
        #expect(engine.decision(for: "scan my Id") == .noChange)
    }
}

@Suite struct RecasedSuggestionPreference {
    /// When the checker's list contains the typed word merely recased
    /// (jake -> Jake), that IS the word -- it outranks any letter-changing
    /// suggestion regardless of list order (jake -> take was a real miss).
    @Test func recasingBeatsLetterChanges() {
        let engine = CorrectionEngine(checker: CannedChecker(canned: [
            "jake": ["take", "Jake", "fake"],
        ]))
        #expect(engine.decision(for: "tell jake") ==
                .correct(to: "Jake", alternatives: ["take", "fake"]))
    }
}

@Suite struct SuggestionDistanceGuard {
    private let engine = CorrectionEngine(checker: CannedChecker(canned: [
        "nkechi": ["Knit"], "saoirse": ["Satires"], "kylian": ["Chilean"],
        "arigato": ["arrogate"], "ilysm": ["asylum"], "unalive": ["unlike"],
        "wierd": ["weird"], "definately": ["definitely"], "thnks": ["thanks"],
    ]))

    /// A suggestion far from what was typed is the checker guessing at a
    /// word it doesn't know (names, slang, loanwords) -- reject past
    /// Damerau-Levenshtein max(1, len/3). Holds even at sentence start,
    /// where the proper-noun guard can't help.
    @Test(arguments: ["Nkechi", "Saoirse", "Kylian", "arigato", "ilysm", "unalive"])
    func farSuggestionsAreGarbage(word: String) {
        #expect(engine.decision(for: word) == .noChange)
    }

    /// Near suggestions still fire: transpositions count as distance 1
    /// (Damerau), long-word phonetic fixes stay within len/3.
    @Test func nearSuggestionsStillCorrect() {
        #expect(engine.decision(for: "wierd") ==
                .correct(to: "weird", alternatives: []))
        #expect(engine.decision(for: "definately") ==
                .correct(to: "definitely", alternatives: []))
        #expect(engine.decision(for: "thnks") ==
                .correct(to: "thanks", alternatives: []))
    }
}

// MARK: - Elision before digits, calendar capitalization

@Suite struct DigitElisionRetrofix {
    /// A digit right after a freshly opened single quote means the quote
    /// was an elision apostrophe ('90s, '99), not an opening quote --
    /// retro-flip it.
    @Test func digitFlipsOpenSingleQuoteToApostrophe() {
        #expect(SmartSymbols.decision(forTyping: "9", before: "like the \u{2018}")
                == .replaceLast(1, with: "\u{2019}9"))
        // A real opening quote before a letter stays open.
        #expect(SmartSymbols.decision(forTyping: "m", before: "the word \u{2018}")
                == .insert("m"))
    }
}

@Suite struct CalendarCapitalization {
    private let engine = CorrectionEngine(checker: CannedChecker(canned: [:]))

    /// Weekdays and unambiguous months typed lowercase capitalize on
    /// commit; march/may stay (common verb/auxiliary homographs).
    @Test func lowercaseDayAndMonthCapitalize() {
        #expect(engine.decision(for: "coming saturday") ==
                .correct(to: "Saturday", alternatives: []))
        #expect(engine.decision(for: "early december") ==
                .correct(to: "December", alternatives: []))
    }

    @Test func homographMonthsAndCapitalizedFormsStay() {
        #expect(engine.decision(for: "we march") == .noChange)
        #expect(engine.decision(for: "you may") == .noChange)
        #expect(engine.decision(for: "coming Saturday") == .noChange)
    }
}

// MARK: - Shift: a smart-space terminal mark always starts a sentence

@Suite struct SmartMarkShiftArm {
    /// The context re-derivation can't know a smart-space period after an
    /// abbreviation ("Ave.") was deliberately terminal -- the insert site
    /// arms the shift directly instead.
    @Test func armOneShotArmsFromOff() {
        var shift = ShiftState()
        shift.armOneShot()
        #expect(shift.mode == .oneShot)
    }

    /// Caps lock and an armed one-shot are never disturbed.
    @Test func armOneShotNeverDowngrades() {
        var shift = ShiftState()
        shift.tapShift(at: 0)
        shift.tapShift(at: 0.1)   // double-tap -> caps lock
        shift.armOneShot()
        #expect(shift.mode == .capsLock)
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
