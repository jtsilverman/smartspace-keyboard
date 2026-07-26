import Testing
import PunctuationEngine

@Test func congratulatoryPhraseRanksExclamationFirst() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "congrats on the new job").first == Candidate(text: "!"))
    #expect(engine.candidates(before: "omg that view").first == Candidate(text: "!"))
}

@Test func questionRulesOutrankExclamationWords() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "how awesome is that").first == Candidate(text: "?"))
}
