import Testing
import PunctuationEngine

@Test func subordinateOpenerRanksCommaFirst() {
    let engine = PunctuationEngine()
    let top = engine.candidates(before: "if you're free tomorrow").first
    #expect(top?.text == ",")
    #expect(top?.endsSentence == false)
    #expect(engine.candidates(before: "as i entered the cabin").first?.text == ",")
    #expect(engine.candidates(before: "even if nobody comes").first?.text == ",")
}

@Test func conjunctionOpenerRanksCommaFirst() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "but actually it is").first?.text == ",")
    #expect(engine.candidates(before: "and sometimes when i open my mouth").first?.text == ",")
}

@Test func whenClauseWithoutAuxiliaryIsSubordinate() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "when you land").first?.text == ",")
    #expect(engine.candidates(before: "when do you land").first == Candidate(text: "?"))
}

@Test func sayVerbEnderRanksQuoteFirst() {
    let engine = PunctuationEngine()
    let top = engine.candidates(before: "she said").first
    #expect(top?.text == "\"")
    #expect(top?.endsSentence == false)
    #expect(engine.candidates(before: "u say").first?.text == "\"")
    #expect(engine.candidates(before: "what did he say").first == Candidate(text: "?"))
}

@Test func quoteNounRanksQuoteFirst() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "ever green quote ever told by jerry").first?.text == "\"")
    #expect(engine.candidates(before: "my painful personal thought").first?.text == "\"")
}

@Test func commaOpenerOutranksMidSentenceQuoteNoun() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "if you quote me on this").first?.text == ",")
    #expect(engine.candidates(before: "but i think a quote would help").first?.text == ",")
}

@Test func timeOfDayGreetingRanksCommaFirst() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "good afternoon").first?.text == ",")
    #expect(engine.candidates(before: "good evening sir").first?.text == ",")
}
