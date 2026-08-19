import Testing
import TypingEngine

/// "teh" corrects to "the"; the checker also offers word completions.
private func slotController() -> AutocorrectController {
    struct Checker: SpellChecking {
        func suggestions(for word: String) -> [String] {
            word.lowercased() == "teh" ? ["the", "ten"] : []
        }
        func completions(for prefix: String) -> [String] {
            ["tehran", "tehachapi"]
        }
    }
    return AutocorrectController(checker: Checker())
}

// Stock's mid-word bar with a pending correction reads
// "literal" | correction (highlight pill) | one more candidate.
// The correction leads the follow slots and a tap applies it.

@Test func pendingCorrectionLeadsTheFollowSlots() {
    var c = slotController()
    c.typingUpdate(context: "so teh")
    #expect(c.barContent == .completions(
        typed: "teh", completions: ["the", "tehran"], correction: "the"))
}

@Test func tappingTheCorrectionSlotAppliesIt() {
    var c = slotController()
    c.typingUpdate(context: "so teh")
    #expect(c.barTapped(slot: 1) == .complete(from: "teh", to: "the"))
}

@Test func tappingTheThirdSlotCompletesInstead() {
    var c = slotController()
    c.typingUpdate(context: "so teh")
    #expect(c.barTapped(slot: 2) == .complete(from: "teh", to: "tehran"))
}

@Test func aCompletionEqualToTheCorrectionDropsOut() {
    struct Checker: SpellChecking {
        func suggestions(for word: String) -> [String] { ["the"] }
        func completions(for prefix: String) -> [String] { ["the", "then"] }
    }
    var c = AutocorrectController(checker: Checker())
    c.typingUpdate(context: "so teh")
    #expect(c.barContent == .completions(
        typed: "teh", completions: ["the", "then"], correction: "the"))
}
