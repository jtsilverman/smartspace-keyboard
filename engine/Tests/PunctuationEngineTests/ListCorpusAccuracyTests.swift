import Testing

// Spec comma-lists AC 3: blind-authored list benchmark. Dev misses may be
// studied to design rules (invariant-first); the test half reports
// aggregate numbers only. Thresholds frozen at first green -- a regression
// below them fails the build.
//
// list-item1 rows carry gold "," (both blind authors said texters WANT the
// comma at item 1), but the shipped hedge is period-first with comma one
// tap away -- so item-1 rows are expected top-1 misses and top-2 hits.
// They gate top-2 only; a future intro-verb rule (spec v2) would move them.

@Test func listDevAccuracyReport() {
    #expect(listCorpusDev.count == 66)
    let s = evalScore(listCorpusDev, predict: enginePredictor(), name: "LIST DEV", printMisses: true)
    #expect(Double(s.top1) / Double(s.n) >= 0.65)
    #expect(Double(s.top2) / Double(s.n) >= 0.90)
}

@Test func listTestAccuracyReport() {
    #expect(listCorpusTest.count == 73)
    let s = evalScore(listCorpusTest, predict: enginePredictor(), name: "LIST TEST", printMisses: false)
    #expect(Double(s.top1) / Double(s.n) >= 0.65)
    #expect(Double(s.top2) / Double(s.n) >= 0.90)
}
