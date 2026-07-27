import Testing
import TypingEngine

@Test func emptyAndBlankContextsStartCapitalized() {
    #expect(CapitalizationRule.shouldCapitalize(before: ""))
    #expect(CapitalizationRule.shouldCapitalize(before: "   "))
}

@Test func sentenceEndersFollowedBySpaceCapitalize() {
    #expect(CapitalizationRule.shouldCapitalize(before: "Cool. "))
    #expect(CapitalizationRule.shouldCapitalize(before: "sup! "))
    #expect(CapitalizationRule.shouldCapitalize(before: "really? "))
}

@Test func newlineStartsANewSentence() {
    #expect(CapitalizationRule.shouldCapitalize(before: "hi\n"))
    #expect(CapitalizationRule.shouldCapitalize(before: "on my way.\n"))
}

@Test func closingQuoteBetweenEnderAndSpaceStillCapitalizes() {
    #expect(CapitalizationRule.shouldCapitalize(before: "He said \"come over.\" "))
    #expect(CapitalizationRule.shouldCapitalize(before: "He said \u{201C}come over.\u{201D} "))
}

@Test func titleAbbreviationsCapitalizeTheNameThatFollows() {
    #expect(CapitalizationRule.shouldCapitalize(before: "Mr. "))
    #expect(CapitalizationRule.shouldCapitalize(before: "Dr. "))
    #expect(CapitalizationRule.shouldCapitalize(before: "meet me at St. "))
}

@Test func midSentenceAbbreviationPeriodsAreCapsNeutral() {
    #expect(!CapitalizationRule.shouldCapitalize(before: "e.g. "))
    #expect(!CapitalizationRule.shouldCapitalize(before: "apples etc. "))
    #expect(!CapitalizationRule.shouldCapitalize(before: "cats vs. "))
    #expect(!CapitalizationRule.shouldCapitalize(before: "at 9 p.m. "))
}

@Test func midSentenceAndMidWordNeverCapitalize() {
    #expect(!CapitalizationRule.shouldCapitalize(before: "hey, "))
    #expect(!CapitalizationRule.shouldCapitalize(before: "she said \u{201C}"))
    #expect(!CapitalizationRule.shouldCapitalize(before: "wor"))
    #expect(!CapitalizationRule.shouldCapitalize(before: "hello "))
}
