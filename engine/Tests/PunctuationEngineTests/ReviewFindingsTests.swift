import Testing
import PunctuationEngine

@Test func dottedAbbreviationGetsNonEndingPeriod() {
    let engine = PunctuationEngine()
    let top = engine.candidates(before: "bring snacks e.g").first
    #expect(top?.text == ".")
    #expect(top?.endsSentence == false)
    #expect(engine.candidates(before: "call me at 5 p.m").first?.endsSentence == false)
}

@Test func apostrophizedFormsMatchTheirPlainRules() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "what's the wifi password").first == Candidate(text: "?"))
    #expect(engine.candidates(before: "let's go").first == Candidate(text: "!"))
    #expect(engine.candidates(before: "what\u{2019}s the plan").first == Candidate(text: "?"))
}

@Test func cycleStateRefusesEmptyCandidates() {
    #expect(CycleState(candidates: []) == nil)
}
