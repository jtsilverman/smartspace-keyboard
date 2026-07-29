import Testing
@testable import TypingEngine

/// Checker with fixed suggestion + completion tables; empty means correct.
private struct TableChecker: SpellChecking {
    let table: [String: [String]]
    var completionTable: [String: [String]] = [:]
    func suggestions(for word: String) -> [String] {
        table[word.lowercased()] ?? []
    }
    func completions(for prefix: String) -> [String] {
        completionTable[prefix.lowercased()] ?? []
    }
}

private func controller(
    table: [String: [String]] = ["teh": ["the", "ten", "tech", "eth", "th"]],
    completions: [String: [String]] = [:],
    lexicon: Set<String> = []
) -> AutocorrectController {
    AutocorrectController(checker: TableChecker(table: table, completionTable: completions),
                          lexicon: lexicon)
}

// Spec AC 1 + 7 (3.4): committing a misspelled word replaces it with the top
// suggestion; the bar shows the original first and at most 2 alternatives.
@Suite struct AutocorrectCommit {
    @Test func misspelledCommitReplacesWithTopSuggestion() {
        var c = controller()
        let commit = c.wordCommitted(context: "hi teh")
        #expect(commit == .replace(original: "teh", corrected: "the",
                                   alternatives: ["ten", "tech"]))
    }

    @Test func barShowsOriginalThenAtMostTwoAlternatives() {
        var c = controller()
        _ = c.wordCommitted(context: "hi teh")
        #expect(c.barContent == .correction(slots: ["teh", "ten", "tech"]))
    }

    @Test func correctWordCommitKeepsAndClearsBar() {
        var c = controller()
        _ = c.wordCommitted(context: "hi teh")
        let commit = c.wordCommitted(context: "hi the hello")
        #expect(commit == .keep)
        #expect(c.barContent == .empty)
    }

    @Test func lexiconWordIsNeverCorrected() {
        var c = controller(lexicon: ["Teh"])
        #expect(c.wordCommitted(context: "hi teh") == .keep)
    }

    @Test func emptyContextKeeps() {
        var c = controller()
        #expect(c.wordCommitted(context: "") == .keep)
    }
}

// Spec AC 2 (3.4): tapping the original word reverts the correction and
// protects the word for the rest of the session (no correction loops).
@Suite struct AutocorrectUndo {
    @Test func undoTapRevertsAndProtects() {
        var c = controller()
        _ = c.wordCommitted(context: "hi teh")
        let action = c.barTapped(slot: 0)
        #expect(action == .undo(original: "teh", corrected: "the"))
        #expect(c.barContent == .empty)
        #expect(c.wordCommitted(context: "later teh") == .keep)
    }

    @Test func tapWithNoActiveContentDoesNothing() {
        var c = controller()
        #expect(c.barTapped(slot: 0) == AutocorrectController.BarAction.none)
    }

    @Test func outOfRangeSlotDoesNothing() {
        var c = controller(table: ["teh": ["the"]])
        _ = c.wordCommitted(context: "hi teh")
        #expect(c.barTapped(slot: 2) == AutocorrectController.BarAction.none)
        #expect(c.barContent == .correction(slots: ["teh"]))
    }
}

// Spec AC 6 (3.4): tapping an alternative swaps the corrected word; the
// former correction becomes an alternative so the user can swap back.
@Suite struct AutocorrectSwap {
    @Test func alternativeTapSwapsCorrectedWord() {
        var c = controller()
        _ = c.wordCommitted(context: "hi teh")
        let action = c.barTapped(slot: 1)
        #expect(action == .swap(from: "the", to: "ten"))
        #expect(c.barContent == .correction(slots: ["teh", "the", "tech"]))
    }

    @Test func undoAfterSwapDeletesTheSwappedWord() {
        var c = controller()
        _ = c.wordCommitted(context: "hi teh")
        _ = c.barTapped(slot: 1)
        #expect(c.barTapped(slot: 0) == .undo(original: "teh", corrected: "ten"))
    }

    @Test func currentCorrectedTracksSwapsAndClears() {
        var c = controller()
        #expect(c.currentCorrected == nil)
        _ = c.wordCommitted(context: "hi teh")
        #expect(c.currentCorrected == "the")
        _ = c.barTapped(slot: 1)
        #expect(c.currentCorrected == "ten")
        c.backspace()
        #expect(c.currentCorrected == nil)
    }
}

// Spec AC 5 (3.4): UILexicon arrives async after keyboard load; adopting it
// must not reset session protection or the active bar.
@Suite struct AutocorrectLexiconUpdate {
    @Test func updateLexiconPreservesProtectionAndActiveBar() {
        var c = controller(table: ["teh": ["the"], "adn": ["and"]])
        _ = c.wordCommitted(context: "hi teh")
        _ = c.barTapped(slot: 0)                    // protect "teh"
        _ = c.wordCommitted(context: "hi teh adn")
        c.updateLexicon(["Jayde"])
        #expect(c.barContent == .correction(slots: ["adn"]))
        #expect(c.wordCommitted(context: "later teh") == .keep)
    }

    @Test func updateLexiconWordsStopBeingCorrected() {
        var c = controller(table: ["jayde": ["jade"]])
        #expect(c.wordCommitted(context: "hi jayde")
                == .replace(original: "jayde", corrected: "jade", alternatives: []))
        c.updateLexicon(["Jayde"])
        #expect(c.wordCommitted(context: "hi jayde") == .keep)
    }
}

// Spec AC 10 (3.4): bar lifecycle at the seams.
@Suite struct AutocorrectBarLifecycle {
    @Test func invalidateBarClearsBarAndKeepsProtection() {
        var c = controller(table: ["teh": ["the"], "adn": ["and"]])
        _ = c.wordCommitted(context: "hi teh")
        _ = c.barTapped(slot: 0)                    // protect "teh"
        _ = c.wordCommitted(context: "hi teh adn")
        #expect(c.barContent == .correction(slots: ["adn"]))
        c.invalidateBar()
        #expect(c.barContent == .empty)
        #expect(c.currentCorrected == nil)
        #expect(c.wordCommitted(context: "later teh") == .keep)
    }

    @Test func backspaceClearsBarButKeepsProtection() {
        var c = controller()
        _ = c.wordCommitted(context: "hi teh")
        _ = c.barTapped(slot: 0)
        _ = c.wordCommitted(context: "again teh")
        c.backspace()
        #expect(c.barContent == .empty)
        #expect(c.wordCommitted(context: "third teh") == .keep)
    }

    @Test func backspaceClosesUndoWindow() {
        var c = controller()
        _ = c.wordCommitted(context: "hi teh")
        c.backspace()
        #expect(c.barTapped(slot: 0) == AutocorrectController.BarAction.none)
        // Not protected: only an undo tap protects.
        #expect(c.wordCommitted(context: "again teh")
                == .replace(original: "teh", corrected: "the",
                            alternatives: ["ten", "tech"]))
    }

    @Test func nextCommitRefillsBarForNewWord() {
        var c = controller(table: ["teh": ["the"], "adn": ["and", "an"]])
        _ = c.wordCommitted(context: "hi teh")
        _ = c.wordCommitted(context: "hi the adn")
        #expect(c.barContent == .correction(slots: ["adn", "an"]))
    }

    // Property: across any interaction sequence the correction bar never
    // exceeds 3 slots and slot 0 is always the original.
    @Test func correctionBarNeverExceedsThreeSlotsAndLeadsWithOriginal() {
        let words = ["teh", "adn", "hello", "teh", "adn"]
        let table = ["teh": ["the", "ten", "tech", "eth"],
                     "adn": ["and", "an", "aden", "adnd", "dan"]]
        var c = controller(table: table)
        var context = ""
        for (i, word) in words.enumerated() {
            context += (context.isEmpty ? "" : " ") + word
            let commit = c.wordCommitted(context: context)
            if case .correction(let slots) = c.barContent {
                #expect(slots.count <= 3)
                if case .replace(let original, _, _) = commit {
                    #expect(slots.first == original)
                }
            }
            switch i % 3 {
            case 0: _ = c.barTapped(slot: 1)
            case 1: c.backspace()
            default: _ = c.barTapped(slot: 0)
            }
        }
    }
}

// Spec completions-bar AC 1/3/8/8b: mid-word completions in the bar.
@Suite struct CompletionBar {
    private func typingController() -> AutocorrectController {
        controller(table: ["teh": ["the"]],
                   completions: ["keyb": ["keyboard", "keybinding", "keyboards"],
                                 "ke": ["keep", "key"]])
    }

    @Test func partialWordServesTypedPlusTwoCompletions() {
        var c = typingController()
        c.typingUpdate(context: "hello keyb")
        #expect(c.barContent == .completions(typed: "keyb",
                                             completions: ["keyboard", "keybinding"]))
    }

    @Test func partialWithNoCompletionsStillShowsTyped() {
        var c = typingController()
        c.typingUpdate(context: "zzq")
        #expect(c.barContent == .completions(typed: "zzq", completions: []))
    }

    @Test func emptyPartialLeavesCorrectionUntouched() {
        var c = typingController()
        _ = c.wordCommitted(context: "hi teh")
        c.typingUpdate(context: "hi the ")
        #expect(c.barContent == .correction(slots: ["teh"]))
    }

    @Test func emptyPartialClearsStaleTypingState() {
        var c = typingController()
        c.typingUpdate(context: "hello keyb")
        c.typingUpdate(context: "hello keyboard ")
        #expect(c.barContent == .empty)
    }

    @Test func firstLetterOfNextWordReplacesCorrectionBar() {
        var c = typingController()
        _ = c.wordCommitted(context: "hi teh")
        #expect(c.barContent == .correction(slots: ["teh"]))
        c.typingUpdate(context: "hi the k")
        #expect(c.barContent == .completions(typed: "k", completions: []))
    }

    @Test func backspaceThenTypingRepopulatesCompletions() {
        var c = typingController()
        _ = c.wordCommitted(context: "hi teh")
        c.backspace()
        c.typingUpdate(context: "hi ke")
        #expect(c.barContent == .completions(typed: "ke", completions: ["keep", "key"]))
    }

    @Test func completionTapReturnsCompleteAndClears() {
        var c = typingController()
        c.typingUpdate(context: "hello keyb")
        #expect(c.barTapped(slot: 1) == .complete(from: "keyb", to: "keyboard"))
        #expect(c.barContent == .empty)
    }

    @Test func verbatimTapAcceptsAndProtects() {
        var c = controller(table: ["teh": ["the"]], completions: [:])
        c.typingUpdate(context: "so teh")
        #expect(c.barTapped(slot: 0) == .acceptTyped(word: "teh"))
        #expect(c.barContent == .empty)
        #expect(c.wordCommitted(context: "later teh") == .keep)
    }

    @Test func outOfRangeCompletionSlotDoesNothing() {
        var c = typingController()
        c.typingUpdate(context: "hello keyb")
        #expect(c.barTapped(slot: 3) == AutocorrectController.BarAction.none)
        #expect(c.barContent == .completions(typed: "keyb",
                                             completions: ["keyboard", "keybinding"]))
    }
}

// Spec completions-bar AC 3/4: session protect verb + seam default.
@Suite struct CompletionSeams {
    @Test func sessionProtectBlocksCorrection() {
        var session = CorrectionSession()
        session.protect("Teh")
        #expect(session.isProtected("teh"))
    }

    @Test func spellCheckingCompletionsDefaultsToEmpty() {
        struct MinimalChecker: SpellChecking {
            func suggestions(for word: String) -> [String] { [] }
        }
        #expect(MinimalChecker().completions(for: "any") == [])
    }
}

// Trailing punctuation/digits mean no partial word: typing "!" after a
// word must not resurrect that word's completions.
@Suite struct CompletionPartialBoundary {
    @Test func trailingPunctuationYieldsNoCompletions() {
        var c = AutocorrectController(checker: TableChecker(
            table: [:], completionTable: ["hi": ["high", "hind"]]))
        c.typingUpdate(context: "hi")
        #expect(c.barContent == .completions(typed: "hi", completions: ["high", "hind"]))
        c.typingUpdate(context: "hi!")
        #expect(c.barContent == .empty)
    }
}
