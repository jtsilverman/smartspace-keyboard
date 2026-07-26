import Testing
import PunctuationEngine

@Test func whWordStartRanksQuestionFirst() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "how are you").first == Candidate(text: "?"))
}
