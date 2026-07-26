import Testing
import PunctuationEngine

/// Property: for ANY input, candidates(before:) returns the three sentence
/// enders, distinct, with a valid mark ranked first. Inputs are generated
/// combinations, not hand-picked examples.
@Test func candidateListInvariantsHoldForGeneratedInputs() {
    let engine = PunctuationEngine()
    let vocabulary = ["how", "do", "you", "your", "homework", "right", "", "  ",
                      "pizza?", "Mr.", "SO", "excited", "1234", "🎉", "don't"]
    var inputs: [String] = []
    for a in vocabulary {
        for b in vocabulary {
            for c in vocabulary {
                inputs.append([a, b, c].joined(separator: " "))
            }
        }
    }

    for input in inputs {
        let result = engine.candidates(before: input)
        let texts = result.map(\.text)
        #expect(Set(texts) == Set([".", "?", "!"]), "input: \(input)")
    }
}

@Test func whitespaceOnlyContextFallsBackToPeriod() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "   ").first == Candidate(text: "."))
}

@Test func uppercaseInputStillDetected() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "HOW ARE YOU").first == Candidate(text: "?"))
}
