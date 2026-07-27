import Testing
@testable import PunctuationEngine

// Scoring is tested against an injected fake predictor with hand-computed
// expectations, so these tests are independent of engine rule behavior.
@Test func evalScoreCountsTop1Top2AndBreakdowns() {
    let rows = [
        EvalRow(text: "a", label: ".", form: "declarative", register: "full"),
        EvalRow(text: "b", label: "?", form: "wh-question", register: "txt"),
        EvalRow(text: "c", label: "?", form: "wh-question", register: "frag"),
        EvalRow(text: "d", label: "!", form: "exclamation", register: "txt"),
    ]
    let fake: (String) -> [String] = { text in
        switch text {
        case "a": return [".", "?"]   // top-1 hit
        case "b": return ["?", "."]   // top-1 hit
        case "c": return [".", "?"]   // top-2 only
        default:  return [".", "?"]   // full miss
        }
    }
    let s = evalScore(rows, predict: fake, name: "FIXTURE", printMisses: false)
    #expect(s.n == 4)
    #expect(s.top1 == 2)
    #expect(s.top2 == 3)
    #expect(s.perLabel["?"]?.top1 == 1)
    #expect(s.perLabel["?"]?.n == 2)
    #expect(s.perForm["wh-question"]?.top1 == 1)
    #expect(s.perForm["wh-question"]?.top2 == 2)
    #expect(s.perForm["exclamation"]?.top2 == 0)
}

@Test func evalScoreEmptyPredictionIsAMiss() {
    let rows = [EvalRow(text: "x", label: ".", form: "declarative", register: "full")]
    let s = evalScore(rows, predict: { _ in [] }, name: "FIXTURE", printMisses: false)
    #expect(s.top1 == 0)
    #expect(s.top2 == 0)
}
