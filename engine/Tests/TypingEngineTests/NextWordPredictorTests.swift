import Testing
import TypingEngine

// Stock's QuickType bar is never empty: at rest it shows three
// predictions. On an empty field or a fresh sentence stock shows the
// I / The / I'm trio; after a word it predicts from that word; when it
// has no specific guess it still fills the bar. Predictions chain: an
// accepted word yields the next trio.

@Test func emptyFieldShowsTheStockTrio() {
    #expect(NextWordPredictor.predictions(after: "") == ["I", "The", "I\u{2019}m"])
}

@Test func aFreshSentenceShowsTheStockTrio() {
    #expect(NextWordPredictor.predictions(after: "Done. ") == ["I", "The", "I\u{2019}m"])
    #expect(NextWordPredictor.predictions(after: "hi\n") == ["I", "The", "I\u{2019}m"])
}

@Test func predictsFromTheLastCommittedWord() {
    #expect(NextWordPredictor.predictions(after: "I ") == ["am", "will", "have"])
    #expect(NextWordPredictor.predictions(after: "thank ").first == "you")
}

@Test func headLookupIgnoresCase() {
    #expect(NextWordPredictor.predictions(after: "Thank ").first == "you")
}

@Test func unknownWordsStillFillTheBar() {
    #expect(NextWordPredictor.predictions(after: "zyzzyva ") == ["the", "to", "and"])
}

@Test func aTrailingPartialWordPredictsFromTheWordBeforeIt() {
    // Mid-word the bar normally shows completions; if the predictor is
    // asked anyway it must not treat the partial as a committed word.
    #expect(NextWordPredictor.predictions(after: "thank yo") == ["you", "God", "goodness"])
}

@Test func theBarIsNeverEmpty() {
    for context in ["", " ", "x ", "hello world ", "3 ", "https://a.b ", "?? "] {
        #expect(NextWordPredictor.predictions(after: context).count == 3,
                "context \(String(reflecting: context))")
    }
}
