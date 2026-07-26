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

@Test func auxiliaryThenPronounRanksQuestionFirst() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "do you want pizza").first == Candidate(text: "?"))
}

@Test func auxiliaryThenDeterminerStaysImperative() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "do your homework").first == Candidate(text: "."))
}

@Test func trailingTagWordRanksQuestionFirst() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "you're coming tonight right").first == Candidate(text: "?"))
}
