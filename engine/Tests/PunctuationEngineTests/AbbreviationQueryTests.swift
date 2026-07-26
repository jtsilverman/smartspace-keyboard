import Testing
import PunctuationEngine

@Test func knownAbbreviationsMatchRawTokensWithDots() {
    #expect(PunctuationEngine.isKnownAbbreviation("Mr."))
    #expect(PunctuationEngine.isKnownAbbreviation("mr"))
    #expect(PunctuationEngine.isKnownAbbreviation("e.g."))
    #expect(PunctuationEngine.isKnownAbbreviation("E.G."))
    #expect(PunctuationEngine.isKnownAbbreviation("Dr."))
}

@Test func ordinaryWordsAreNotAbbreviations() {
    #expect(!PunctuationEngine.isKnownAbbreviation("over."))
    #expect(!PunctuationEngine.isKnownAbbreviation("word"))
    #expect(!PunctuationEngine.isKnownAbbreviation(""))
}
