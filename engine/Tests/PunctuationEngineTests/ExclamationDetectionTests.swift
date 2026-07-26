import Testing
import PunctuationEngine

@Test func congratulatoryPhraseRanksExclamationFirst() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "congrats on the new job").first == Candidate(text: "!"))
}
