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

@Test func nonImperativeAuxiliaryQuestionsNeedNoPronoun() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "was your day good").first == Candidate(text: "?"))
    #expect(engine.candidates(before: "did your mom call").first == Candidate(text: "?"))
    #expect(engine.candidates(before: "can your brother come").first == Candidate(text: "?"))
}

@Test func imperativeCapableAuxiliariesStillGateOnPronoun() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "have a great day").first == Candidate(text: "."))
}

@Test func finalNoIsAStatementNotATag() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "just say no").first == Candidate(text: "."))
}

@Test func verbFirstRequestRanksQuestionFirst() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "want to grab dinner").first == Candidate(text: "?"))
    #expect(engine.candidates(before: "wanna come with us").first == Candidate(text: "?"))
}
