import Testing
import PunctuationEngine

@Test func abbreviationGetsPeriodWithoutSentenceEnd() {
    let engine = PunctuationEngine()
    let top = engine.candidates(before: "i had coffee with mr").first
    #expect(top?.text == ".")
    #expect(top?.endsSentence == false)
}

@Test func ordinaryPeriodEndsSentence() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "i went to the store").first?.endsSentence == true)
}
