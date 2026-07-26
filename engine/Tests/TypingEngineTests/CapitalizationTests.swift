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

@Test func abbreviationPeriodsAreCapsNeutral() {
    #expect(!CapitalizationRule.shouldCapitalize(before: "Mr. "))
    #expect(!CapitalizationRule.shouldCapitalize(before: "e.g. "))
}

@Test func midSentenceAndMidWordNeverCapitalize() {
    #expect(!CapitalizationRule.shouldCapitalize(before: "hey, "))
    #expect(!CapitalizationRule.shouldCapitalize(before: "she said \u{201C}"))
    #expect(!CapitalizationRule.shouldCapitalize(before: "wor"))
    #expect(!CapitalizationRule.shouldCapitalize(before: "hello "))
}
