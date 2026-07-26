import Testing
import TypingEngine

/// Property: for ANY context, lastWord is nil or a clean correctable word --
/// letter-bounded, free of whitespace and digits, made only of letters,
/// apostrophes, and hyphens, and present verbatim in the context. Inputs are
/// generated combinations, not hand-picked examples.
@Test func lastWordInvariantsHoldForGeneratedContexts() {
    let vocabulary = ["teh", "Teh", "don't", "don\u{2019}t", "wierd-looking",
                      "1234", "4b", "http://x.com", "a@b.com", "(teh)", "teh,",
                      "", "  ", "🎉", "ASAP", "e.g."]
    var inputs: [String] = []
    for a in vocabulary {
        for b in vocabulary {
            for c in vocabulary {
                inputs.append([a, b, c].joined(separator: " "))
            }
        }
    }

    for input in inputs {
        guard let word = WordBoundary.lastWord(in: input) else {
            continue
        }
        #expect(input.last?.isWhitespace == false, "input: \(input)")
        #expect(word.first?.isLetter == true && word.last?.isLetter == true,
                "input: \(input) word: \(word)")
        #expect(word.allSatisfy { $0.isLetter || $0 == "'" || $0 == "\u{2019}" || $0 == "-" },
                "input: \(input) word: \(word)")
        let appearsVerbatim = input.indices.contains { input[$0...].hasPrefix(word) }
        #expect(appearsVerbatim, "input: \(input) word: \(word)")
    }
}
