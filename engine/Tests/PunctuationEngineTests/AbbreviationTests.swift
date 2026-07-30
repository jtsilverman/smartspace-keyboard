import Testing
import PunctuationEngine

// v4 criterion change: the double-space gesture ends the sentence, so the
// abbreviation rule's period is terminal; only the period-first ranking is
// abbreviation-specific now.
@Test func abbreviationKeepsPeriodFirstRanking() {
    let engine = PunctuationEngine()
    let top = engine.candidates(before: "i had coffee with mr").first
    #expect(top?.text == ".")
    #expect(top?.endsSentence == true)
}

@Test func ordinaryPeriodEndsSentence() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "i went to the store").first?.endsSentence == true)
}
