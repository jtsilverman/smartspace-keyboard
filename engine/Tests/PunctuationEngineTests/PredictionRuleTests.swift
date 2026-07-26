import Testing
import PunctuationEngine

@Test func predictionNamesTheRuleThatFired() {
    let engine = PunctuationEngine()
    #expect(engine.prediction(before: "how are you").rule == .question)
    #expect(engine.prediction(before: "congrats on the job").rule == .exclamation)
    #expect(engine.prediction(before: "if you get there first").rule == .comma)
    #expect(engine.prediction(before: "she said").rule == .quote)
    #expect(engine.prediction(before: "see mr").rule == .abbreviation)
    #expect(engine.prediction(before: "see e.g").rule == .dottedAbbreviation)
    #expect(engine.prediction(before: "done. ").rule == .terminalGuard)
    #expect(engine.prediction(before: "i went home").rule == .fallback)
}

/// Property: prediction(before:) and candidates(before:) never disagree --
/// the rule label is an annotation, not a second ranking path.
@Test func predictionCandidatesMatchCandidatesForGeneratedInputs() {
    let engine = PunctuationEngine()
    let vocabulary = ["how", "you", "said", "mr", "e.g", "done.", "congrats",
                      "if", "went", "", " ", "pizza?", "don't", "SO"]
    for a in vocabulary {
        for b in vocabulary {
            for c in vocabulary {
                let input = [a, b, c].joined(separator: " ")
                #expect(engine.prediction(before: input).candidates ==
                        engine.candidates(before: input), "input: \(input)")
            }
        }
    }
}
