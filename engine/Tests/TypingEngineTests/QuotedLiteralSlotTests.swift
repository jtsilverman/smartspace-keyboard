import Testing
import TypingEngine

/// Checker for the quoted-literal tests: "teh" is the one misspelling.
private func quotingController() -> AutocorrectController {
    struct Checker: SpellChecking {
        func suggestions(for word: String) -> [String] {
            word.lowercased() == "teh" ? ["the"] : []
        }
        func completions(for prefix: String) -> [String] { [] }
    }
    return AutocorrectController(checker: Checker())
}

// Stock renders the typed word in quotation marks in its slot when a
// commit would correct it -- the "keep what I typed" tell (research
// wf_1ac9e72d-a76, axes 3+4: literal in quotes when the word is not
// recognized or a correction is proposed). A clean word, a protected
// word, and a lexicon word show unquoted.

@Test func correctablePartialQuotesTheTypedSlot() {
    var c = quotingController()
    c.typingUpdate(context: "so teh")
    #expect(c.barContent == .completions(typed: "teh", completions: ["the"], correction: "the"))
}

@Test func cleanPartialStaysUnquoted() {
    var c = quotingController()
    c.typingUpdate(context: "so the")
    #expect(c.barContent == .completions(typed: "the", completions: [], correction: nil))
}

@Test func protectedWordStaysUnquoted() {
    var c = quotingController()
    c.typingUpdate(context: "so teh")
    _ = c.barTapped(slot: 0)    // accept typed -> session protect
    c.typingUpdate(context: "later teh")
    #expect(c.barContent == .completions(typed: "teh", completions: [], correction: nil))
}

@Test func lexiconWordStaysUnquoted() {
    struct Checker: SpellChecking {
        func suggestions(for word: String) -> [String] { ["the"] }
        func completions(for prefix: String) -> [String] { [] }
    }
    var c = AutocorrectController(checker: Checker(), lexicon: ["teh"])
    c.typingUpdate(context: "so teh")
    #expect(c.barContent == .completions(typed: "teh", completions: [], correction: nil))
}
