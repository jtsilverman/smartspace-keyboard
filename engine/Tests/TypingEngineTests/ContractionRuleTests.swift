import Testing
import TypingEngine

@Test func contractionsGainCurlyApostrophes() {
    #expect(ContractionRule.transform("dont") == "don\u{2019}t")
    #expect(ContractionRule.transform("cant") == "can\u{2019}t")
    #expect(ContractionRule.transform("didnt") == "didn\u{2019}t")
    #expect(ContractionRule.transform("youre") == "you\u{2019}re")
    #expect(ContractionRule.transform("thats") == "that\u{2019}s")
}

@Test func standaloneIAndItsContractionsCapitalize() {
    #expect(ContractionRule.transform("i") == "I")
    #expect(ContractionRule.transform("im") == "I\u{2019}m")
    #expect(ContractionRule.transform("ive") == "I\u{2019}ve")
    #expect(ContractionRule.transform("i'm") == "I\u{2019}m")
    #expect(ContractionRule.transform("i\u{2019}m") == "I\u{2019}m")
}

@Test func ambiguousRealWordsAreNeverTransformed() {
    for word in ["its", "ill", "id", "well", "shell", "were", "lets", "wont", "hell"] {
        #expect(ContractionRule.transform(word) == nil, "word: \(word)")
    }
}

@Test func leadingCapitalSurvivesTheTransform() {
    #expect(ContractionRule.transform("Dont") == "Don\u{2019}t")
    #expect(ContractionRule.transform("Thats") == "That\u{2019}s")
}

@Test func ordinaryWordsPassThroughUntouched() {
    #expect(ContractionRule.transform("hello") == nil)
    #expect(ContractionRule.transform("in") == nil)
    #expect(ContractionRule.transform("") == nil)
}
