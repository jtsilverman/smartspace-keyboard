import Testing
import PunctuationEngine

private func score(_ set: [(text: String, label: String)], name: String,
                   printMisses: Bool) -> (top1: Int, top2: Int) {
    let engine = PunctuationEngine()
    var top1 = 0, top2 = 0
    var missesByLabel: [String: Int] = [:]
    for item in set {
        let ranked = engine.candidates(before: item.text).map(\.text)
        if ranked.first == item.label {
            top1 += 1
            top2 += 1
        } else {
            missesByLabel[item.label, default: 0] += 1
            if ranked.prefix(2).contains(item.label) { top2 += 1 }
            if printMisses {
                print("MISS dev: \"\(item.text)\" expected \(item.label) got \(ranked.joined(separator: " "))")
            }
        }
    }
    let n = set.count
    print("REAL \(name) TOP-1: \(top1)/\(n) = \(top1 * 100 / n)%   TOP-2: \(top2)/\(n) = \(top2 * 100 / n)%   misses by label: \(missesByLabel.sorted(by: { $0.key < $1.key }))")
    return (top1, top2)
}

/// Dev half: misses are printed and may be studied to design rules.
@Test func realDevAccuracyReport() {
    #expect(realCorpusDev.count == 250)
    let s = score(realCorpusDev, name: "DEV ", printMisses: true)
    #expect(s.top1 > 0)
}

/// Held-out half: aggregate score ONLY. Never print or study its sentences.
@Test func realTestAccuracyReport() {
    #expect(realCorpusTest.count == 250)
    let s = score(realCorpusTest, name: "TEST", printMisses: false)
    #expect(s.top1 > 0)
}
