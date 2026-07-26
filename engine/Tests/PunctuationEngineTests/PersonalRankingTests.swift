import Testing
import PunctuationEngine

private func outcome(_ rule: PredictionRule, kept: String) -> OutcomeRecord {
    OutcomeRecord(rule: rule, guess: "?", kept: kept,
                  cycleTaps: 0, lengthBucket: .short)
}

private let questionPrediction = Prediction(rule: .question, candidates: [
    Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!"),
    Candidate(text: ",", endsSentence: false),
])

@Test func fewOutcomesLeaveEngineOrderUntouched() {
    var ranking = PersonalRanking()
    for _ in 1...4 {
        ranking.record(outcome(.question, kept: "."))
    }
    #expect(ranking.reranked(questionPrediction) == questionPrediction.candidates)
}

@Test func enoughKeepsOfAnotherMarkPromoteIt() {
    var ranking = PersonalRanking()
    for _ in 1...5 {
        ranking.record(outcome(.question, kept: "."))
    }
    #expect(ranking.reranked(questionPrediction).map(\.text) == [".", "?", "!", ","])
}

@Test func tiesAndUncountedMarksKeepEngineOrder() {
    var ranking = PersonalRanking()
    for _ in 1...3 { ranking.record(outcome(.question, kept: ".")) }
    for _ in 1...3 { ranking.record(outcome(.question, kept: "!")) }
    // "." and "!" tie at 3; engine order between them is ? . ! so the
    // pair rises above "?" but keeps . before !
    #expect(ranking.reranked(questionPrediction).map(\.text) == [".", "!", "?", ","])
}

@Test func outcomesForOneRuleNeverTouchAnother() {
    var ranking = PersonalRanking()
    for _ in 1...9 {
        ranking.record(outcome(.exclamation, kept: "."))
    }
    #expect(ranking.reranked(questionPrediction) == questionPrediction.candidates)
}

@Test func rerankingPreservesTheCandidateSet() {
    var ranking = PersonalRanking()
    let marks = ["?", ".", "!", ",", "\""]
    for (i, mark) in marks.enumerated() {
        for _ in 0...(i * 3) {
            ranking.record(outcome(.fallback, kept: mark))
        }
    }
    let prediction = Prediction(rule: .fallback,
                                candidates: marks.map { Candidate(text: $0) })
    let reranked = ranking.reranked(prediction)
    #expect(Set(reranked.map(\.text)) == Set(marks))
    #expect(reranked.count == marks.count)
}
