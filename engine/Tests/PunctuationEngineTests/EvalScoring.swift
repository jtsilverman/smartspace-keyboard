import PunctuationEngine

/// One benchmark row: the typed text, its gold mark, and the taxonomy cell it
/// was generated for (scenario form + register) so misses cluster by type.
struct EvalRow {
    let text: String
    let label: String
    let form: String
    let register: String
}

struct SliceScore {
    var n = 0
    var top1 = 0
    var top2 = 0
}

struct EvalScore {
    var n = 0
    var top1 = 0
    var top2 = 0
    var perLabel: [String: SliceScore] = [:]
    var perForm: [String: SliceScore] = [:]
}

/// Scores rows against any predictor (the engine in production, a fake in
/// tests). Prints an aggregate line plus per-label and per-form breakdowns;
/// misses print only when the set's charter allows studying them.
@discardableResult
func evalScore(_ rows: [EvalRow], predict: (String) -> [String], name: String,
               printMisses: Bool) -> EvalScore {
    var s = EvalScore()
    for row in rows {
        let ranked = predict(row.text)
        let hit1 = ranked.first == row.label
        let hit2 = ranked.prefix(2).contains(row.label)
        s.n += 1
        s.perLabel[row.label, default: SliceScore()].n += 1
        s.perForm[row.form, default: SliceScore()].n += 1
        if hit1 {
            s.top1 += 1
            s.perLabel[row.label]!.top1 += 1
            s.perForm[row.form]!.top1 += 1
        }
        if hit2 {
            s.top2 += 1
            s.perLabel[row.label]!.top2 += 1
            s.perForm[row.form]!.top2 += 1
        }
        if !hit1 && printMisses {
            print("MISS \(name) [\(row.form)/\(row.register)] \"\(row.text)\" expected \(row.label) got \(ranked.joined(separator: " "))")
        }
    }
    func pct(_ a: Int, _ b: Int) -> String { b == 0 ? "-" : "\(a * 100 / b)%" }
    print("EVAL \(name) TOP-1: \(s.top1)/\(s.n) = \(pct(s.top1, s.n))   TOP-2: \(s.top2)/\(s.n) = \(pct(s.top2, s.n))")
    for (label, slice) in s.perLabel.sorted(by: { $0.key < $1.key }) {
        print("  label \(label): top1 \(pct(slice.top1, slice.n)) top2 \(pct(slice.top2, slice.n)) (n=\(slice.n))")
    }
    for (form, slice) in s.perForm.sorted(by: { $0.key < $1.key }) {
        print("  form \(form): top1 \(pct(slice.top1, slice.n)) top2 \(pct(slice.top2, slice.n)) (n=\(slice.n))")
    }
    return s
}

/// The production predictor: the engine's ranked candidate marks.
func enginePredictor() -> (String) -> [String] {
    let engine = PunctuationEngine()
    return { text in engine.candidates(before: text).map(\.text) }
}
