import Testing
import PunctuationEngine

/// The headline eval: real SMS sentences, sender-labeled (see RealCorpus.swift
/// provenance). No pass threshold yet -- first run establishes the honest
/// baseline; rule work then raises it. Guard only: metrics must be computable.
@Test func realCorpusAccuracyReport() {
    #expect(realCorpus.count == 500)

    let engine = PunctuationEngine()
    var top1 = 0, top2 = 0
    var missesByLabel: [String: Int] = [:]
    for item in realCorpus {
        let ranked = engine.candidates(before: item.text).map(\.text)
        if ranked.first == item.label {
            top1 += 1
            top2 += 1
        } else {
            missesByLabel[item.label, default: 0] += 1
            if ranked.prefix(2).contains(item.label) {
                top2 += 1
            }
        }
    }

    print("REAL TOP-1: \(top1)/500 = \(top1 / 5)%  (right on the first guess)")
    print("REAL TOP-2: \(top2)/500 = \(top2 / 5)%  (right within one cycle tap)")
    print("REAL misses by expected mark: \(missesByLabel.sorted(by: { $0.value > $1.value }))")
    #expect(top1 > 0)
}
