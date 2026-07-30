import Testing
import PunctuationEngine

// v4 criterion change: double-space is the end-my-sentence gesture, so the
// smart period ends the sentence even after an abbreviation (the rule keeps
// its period-first ranking). See SmartPeriodAlwaysTerminal.
@Test func dottedAbbreviationKeepsPeriodFirstRanking() {
    let engine = PunctuationEngine()
    let top = engine.candidates(before: "bring snacks e.g").first
    #expect(top?.text == ".")
    #expect(top?.endsSentence == true)
    #expect(engine.candidates(before: "call me at 5 p.m").first?.text == ".")
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
