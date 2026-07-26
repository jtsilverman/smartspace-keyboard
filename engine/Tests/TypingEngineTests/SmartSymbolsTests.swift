import Testing
import TypingEngine

@Test func doubleQuoteOpensAfterStartWhitespaceAndBrackets() {
    #expect(SmartSymbols.decision(forTyping: "\"", before: "") == .insert("\u{201C}"))
    #expect(SmartSymbols.decision(forTyping: "\"", before: "she said ") == .insert("\u{201C}"))
    #expect(SmartSymbols.decision(forTyping: "\"", before: "read (") == .insert("\u{201C}"))
}

@Test func doubleQuoteClosesAfterWordsAndPunctuation() {
    #expect(SmartSymbols.decision(forTyping: "\"", before: "\u{201C}hi") == .insert("\u{201D}"))
    #expect(SmartSymbols.decision(forTyping: "\"", before: "\u{201C}come over.") == .insert("\u{201D}"))
}

@Test func singleQuoteIsApostropheMidWordAndOpensAfterWhitespace() {
    #expect(SmartSymbols.decision(forTyping: "'", before: "don") == .insert("\u{2019}"))
    #expect(SmartSymbols.decision(forTyping: "'", before: "rock ") == .insert("\u{2018}"))
}

@Test func doubleHyphenCollapsesToEmDash() {
    #expect(SmartSymbols.decision(forTyping: "-", before: "wait-") ==
        .replacePrevious(with: "\u{2014}"))
    #expect(SmartSymbols.decision(forTyping: "-", before: "wait") == .insert("-"))
    #expect(SmartSymbols.decision(forTyping: "-", before: "wait\u{2014}") == .insert("-"))
}

@Test func ordinaryCharactersPassThrough() {
    #expect(SmartSymbols.decision(forTyping: "a", before: "hey ") == .insert("a"))
    #expect(SmartSymbols.decision(forTyping: "!", before: "wow") == .insert("!"))
}
