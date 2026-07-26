import Testing
import PunctuationEngine

@Test func lengthBucketsSplitAtThreeAndEightWords() {
    #expect(LengthBucket(wordCount: 1) == .short)
    #expect(LengthBucket(wordCount: 3) == .short)
    #expect(LengthBucket(wordCount: 4) == .medium)
    #expect(LengthBucket(wordCount: 8) == .medium)
    #expect(LengthBucket(wordCount: 9) == .long)
    #expect(LengthBucket(wordCount: 25) == .long)
    #expect(LengthBucket(wordCount: 0) == .short)
}

@Test func statsAggregateWinsLossesAndCycling() {
    let records = [
        OutcomeRecord(rule: .question, guess: "?", kept: "?",
                      cycleTaps: 0, lengthBucket: .short),
        OutcomeRecord(rule: .question, guess: "?", kept: ".",
                      cycleTaps: 1, lengthBucket: .medium),
        OutcomeRecord(rule: .fallback, guess: ".", kept: ".",
                      cycleTaps: 0, lengthBucket: .long),
        OutcomeRecord(rule: .exclamation, guess: "!", kept: "!",
                      cycleTaps: 2, lengthBucket: .short),
    ]
    let stats = OutcomeStats(records)
    #expect(stats.total == 4)
    #expect(stats.keptWithoutCycling == 2)
    #expect(stats.keptByMark == ["?": 1, ".": 2, "!": 1])
    #expect(stats.winsByRule == [.question: 1, .fallback: 1, .exclamation: 1])
    #expect(stats.lossesByRule == [.question: 1])
}

@Test func emptyRecordsYieldZeroStats() {
    let stats = OutcomeStats([])
    #expect(stats.total == 0)
    #expect(stats.keptWithoutCycling == 0)
    #expect(stats.keptByMark.isEmpty)
    #expect(stats.winsByRule.isEmpty)
    #expect(stats.lossesByRule.isEmpty)
}
