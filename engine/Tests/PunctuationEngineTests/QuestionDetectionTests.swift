import Testing
import PunctuationEngine

@Test func whWordStartRanksQuestionFirst() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "how are you").first == Candidate(text: "?"))
}

@Test func onlyCurrentSentenceCounts() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "How was it? we got the keys").first == Candidate(text: "."))
}
