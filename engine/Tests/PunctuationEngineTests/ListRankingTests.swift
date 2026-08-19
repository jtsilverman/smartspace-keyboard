import Testing
@testable import PunctuationEngine

// Spec comma-lists AC 1: comma is one cycle tap from period in every
// period-first order (and period already sits second in the comma-first
// order), so a list boundary never costs more than one tap either way.
@Suite struct CommaSecondRankingTests {
    private let engine = PunctuationEngine()

    @Test func fallbackRanksCommaSecond() {
        let texts = engine.prediction(before: "we need chips").candidates.map(\.text)
        #expect(texts == [".", ",", "?", "!", "\""])
    }

    @Test func abbreviationOrdersRankCommaSecond() {
        #expect(engine.prediction(before: "see you at the appt").candidates.map(\.text)
                == [".", ",", "?", "!", "\""])
        #expect(engine.prediction(before: "see you at 5 p.m").candidates.map(\.text)
                == [".", ",", "?", "!", "\""])
    }

    @Test func firstPersonCompletionKeepsExclamationInTopThree() {
        // The v4 excited-news tweak survives: ! stays one tap past comma.
        let texts = engine.prediction(before: "i finally got the job").candidates.map(\.text)
        #expect(texts == [".", ",", "!", "?", "\""])
    }

    @Test func commaFirstOrderKeepsPeriodSecond() {
        let texts = engine.prediction(before: "if you want").candidates.map(\.text)
        #expect(texts == [",", ".", "?", "!", "\""])
    }

    @Test func questionOrderUnchanged() {
        let texts = engine.prediction(before: "are you coming").candidates.map(\.text)
        #expect(texts == ["?", ".", "!", ",", "\""])
    }
}

// Spec comma-lists AC 2: from item 2 of a list onward the engine knows --
// a sentence with a comma boundary and a short next chunk guesses comma
// first, until an "and"/"or" chunk closes the list.
@Suite struct ListRuleTests {
    private let engine = PunctuationEngine()

    @Test func secondListItemGuessesCommaFirst() {
        let p = engine.prediction(before: "we need chips, watermelon")
        #expect(p.rule == .list)
        #expect(p.candidates.map(\.text) == [",", ".", "?", "!", "\""])
    }

    @Test func deepListItemStaysCommaFirst() {
        let p = engine.prediction(before: "we need chips, watermelon, ice")
        #expect(p.rule == .list)
        #expect(p.candidates.first?.text == ",")
    }

    @Test func andChunkClosesTheList() {
        // Jake's example: "i need chips, watermoelon, ice, and sprite."
        let p = engine.prediction(before: "i need chips, watermelon, ice, and sprite")
        #expect(p.rule != .list)
        #expect(p.candidates.first?.text == ".")
    }

    @Test func orChunkClosesTheList() {
        let p = engine.prediction(before: "pizza, thai, or sushi")
        #expect(p.rule != .list)
        #expect(p.candidates.first?.text == ".")
    }

    @Test func questionAfterCommaStillWinsOverList() {
        let p = engine.prediction(before: "just got home babe, are you still awake")
        #expect(p.rule == .question)
    }

    @Test func longChunkAfterCommaIsNotAListItem() {
        let p = engine.prediction(before: "she brought snacks, we ended up staying for the whole game")
        #expect(p.rule == .fallback)
        #expect(p.candidates.first?.text == ".")
    }

    @Test func noCommaMeansNoListRule() {
        let p = engine.prediction(before: "we need chips")
        #expect(p.rule == .fallback)
    }

    @Test func thousandsSeparatorIsNotAListBoundary() {
        // Reviewer finding: digit-grouping commas are not list commas.
        for text in ["it cost 3,000 dollars", "rent is 1,200 a month",
                     "score was 100,000 points"] {
            let p = engine.prediction(before: text)
            #expect(p.rule == .fallback, "input: \(text)")
            #expect(p.candidates.first?.text == ".", "input: \(text)")
        }
    }

    @Test func realListCommaStillFiresNextToANumber() {
        let p = engine.prediction(before: "we need 3,000 cups, plates")
        #expect(p.rule == .list)
        #expect(p.candidates.first?.text == ",")
    }
}
