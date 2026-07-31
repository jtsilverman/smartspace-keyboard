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
        #expect(engine.prediction(before: "meet dr.").candidates.map(\.text)
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
