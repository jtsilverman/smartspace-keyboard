import Testing
@testable import TypingEngine

/// Checker with a fixed suggestion table; empty list means correctly spelled.
private struct TableChecker: SpellChecking {
    let table: [String: [String]]
    func suggestions(for word: String) -> [String] {
        table[word.lowercased()] ?? []
    }
}

private func controller(
    table: [String: [String]] = ["teh": ["the", "ten", "tech", "eth", "th"]],
    lexicon: Set<String> = []
) -> AutocorrectController {
    AutocorrectController(checker: TableChecker(table: table), lexicon: lexicon)
}

// Spec AC 1 + 7: committing a misspelled word replaces it with the top
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
        #expect(c.barSlots == ["teh", "ten", "tech"])
    }

    @Test func correctWordCommitKeepsAndClearsBar() {
        var c = controller()
        _ = c.wordCommitted(context: "hi teh")
        let commit = c.wordCommitted(context: "hi the hello")
        #expect(commit == .keep)
        #expect(c.barSlots.isEmpty)
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

// Spec AC 2: tapping the original word reverts the correction and protects
// the word for the rest of the session (no correction loops).
@Suite struct AutocorrectUndo {
    @Test func undoTapRevertsAndProtects() {
        var c = controller()
        _ = c.wordCommitted(context: "hi teh")
        let action = c.barTapped(slot: 0)
        #expect(action == .undo(original: "teh", corrected: "the"))
        #expect(c.barSlots.isEmpty)
        #expect(c.wordCommitted(context: "later teh") == .keep)
    }

    @Test func tapWithNoActiveCorrectionDoesNothing() {
        var c = controller()
        #expect(c.barTapped(slot: 0) == AutocorrectController.BarAction.none)
    }

    @Test func outOfRangeSlotDoesNothing() {
        var c = controller(table: ["teh": ["the"]])
        _ = c.wordCommitted(context: "hi teh")
        #expect(c.barTapped(slot: 2) == AutocorrectController.BarAction.none)
        #expect(c.barSlots == ["teh"])
    }
}

// Spec AC 6: tapping an alternative swaps the corrected word for it; the
// former correction becomes an alternative so the user can swap back.
@Suite struct AutocorrectSwap {
    @Test func alternativeTapSwapsCorrectedWord() {
        var c = controller()
        _ = c.wordCommitted(context: "hi teh")
        let action = c.barTapped(slot: 1)
        #expect(action == .swap(from: "the", to: "ten"))
        #expect(c.barSlots == ["teh", "the", "tech"])
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

// Spec AC 5: UILexicon arrives async after keyboard load; adopting it must
// not reset session protection or the active bar.
@Suite struct AutocorrectLexiconUpdate {
    @Test func updateLexiconPreservesProtectionAndActiveBar() {
        var c = controller(table: ["teh": ["the"], "adn": ["and"]])
        _ = c.wordCommitted(context: "hi teh")
        _ = c.barTapped(slot: 0)                    // protect "teh"
        _ = c.wordCommitted(context: "hi teh adn")  // active bar for "adn"
        c.updateLexicon(["Jayde"])
        #expect(c.barSlots == ["adn"])
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

// Spec AC 10: bar lifecycle at the seams.
@Suite struct AutocorrectBarLifecycle {
    @Test func backspaceClearsBarButKeepsProtection() {
        var c = controller()
        _ = c.wordCommitted(context: "hi teh")
        _ = c.barTapped(slot: 0)
        _ = c.wordCommitted(context: "again teh")
        c.backspace()
        #expect(c.barSlots.isEmpty)
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
        #expect(c.barSlots == ["adn", "an"])
    }

    // Property: across any interaction sequence the bar never exceeds
    // 3 slots and slot 0 is always the word the correction started from.
    @Test func barNeverExceedsThreeSlotsAndLeadsWithOriginal() {
        let words = ["teh", "adn", "hello", "teh", "adn"]
        let table = ["teh": ["the", "ten", "tech", "eth"],
                     "adn": ["and", "an", "aden", "adnd", "dan"]]
        var c = controller(table: table)
        var context = ""
        for (i, word) in words.enumerated() {
            context += (context.isEmpty ? "" : " ") + word
            let commit = c.wordCommitted(context: context)
            #expect(c.barSlots.count <= 3)
            if case .replace(let original, _, _) = commit {
                #expect(c.barSlots.first == original)
            }
            switch i % 3 {
            case 0: _ = c.barTapped(slot: 1)
            case 1: c.backspace()
            default: _ = c.barTapped(slot: 0)
            }
            #expect(c.barSlots.count <= 3)
        }
    }
}
