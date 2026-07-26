import Testing
import TypingEngine

@Test func trailingWordIsExtractedWithRawCasing() {
    #expect(WordBoundary.lastWord(in: "hello teh") == "teh")
    #expect(WordBoundary.lastWord(in: "ok Teh") == "Teh")
    #expect(WordBoundary.lastWord(in: "teh") == "teh")
}

@Test func apostrophesAndHyphensStayPartOfTheWord() {
    #expect(WordBoundary.lastWord(in: "i dont") == "dont")
    #expect(WordBoundary.lastWord(in: "it's realy") == "realy")
    #expect(WordBoundary.lastWord(in: "some wierd-looking") == "wierd-looking")
    #expect(WordBoundary.lastWord(in: "she said don\u{2019}t") == "don\u{2019}t")
}

@Test func trailingPunctuationIsStrippedFromTheWord() {
    #expect(WordBoundary.lastWord(in: "wait teh,") == "teh")
    #expect(WordBoundary.lastWord(in: "wait teh!") == "teh")
    #expect(WordBoundary.lastWord(in: "(teh)") == "teh")
}

@Test func emptyAndWhitespaceContextsYieldNoWord() {
    #expect(WordBoundary.lastWord(in: "") == nil)
    #expect(WordBoundary.lastWord(in: "   ") == nil)
    #expect(WordBoundary.lastWord(in: "hello ") == nil)
}

@Test func digitsUrlsAndAddressesAreNotCorrectableWords() {
    #expect(WordBoundary.lastWord(in: "call me at 5551234") == nil)
    #expect(WordBoundary.lastWord(in: "see http://example.com") == nil)
    #expect(WordBoundary.lastWord(in: "mail jake@test.com") == nil)
    #expect(WordBoundary.lastWord(in: "room 4b") == nil)
    #expect(WordBoundary.lastWord(in: "version 1.2.3") == nil)
}
