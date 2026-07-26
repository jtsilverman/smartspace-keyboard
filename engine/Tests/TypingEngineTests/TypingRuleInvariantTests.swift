import Testing
import TypingEngine

/// Property: over generated contexts (including emoji, curly quotes, bare
/// punctuation), the rules never trap on index math, a context ending in a
/// letter never capitalizes, and a hyphen only collapses to an em dash when
/// one directly precedes it.
@Test func typingRulesHoldInvariantsOnGeneratedContexts() {
    let vocabulary = ["hi", "Mr.", "e.g.", "over.\u{201D}", "🎉", "\u{201C}",
                      "--", "-", "'", "\"", "", " ", "\n", "i", "dont", "a."]
    var contexts: [String] = [""]
    for a in vocabulary {
        for b in vocabulary {
            for c in vocabulary {
                contexts.append(a + b + c)
            }
        }
    }

    for context in contexts {
        let caps = CapitalizationRule.shouldCapitalize(before: context)
        if context.last?.isLetter == true {
            #expect(!caps, "context: \(context)")
        }
        for char in ["\"", "'", "-", "x"] as [Character] {
            let decision = SmartSymbols.decision(forTyping: char, before: context)
            if case .replacePrevious = decision {
                #expect(char == "-" && context.last == "-", "context: \(context)")
            }
        }
    }
}
