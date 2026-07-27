import Testing

/// Blind benchmark: sentences authored and labeled with zero engine knowledge.
/// Dev misses may be studied to design rules (invariant-first, never one patch
/// per sentence); the test half reports aggregate numbers only.
@Test func blindDevAccuracyReport() {
    #expect(blindCorpusDev.count == 598)
    let s = evalScore(blindCorpusDev, predict: enginePredictor(), name: "BLIND DEV", printMisses: true)
    #expect(s.top1 > 0)
}

@Test func blindTestAccuracyReport() {
    #expect(blindCorpusTest.count == 598)
    let s = evalScore(blindCorpusTest, predict: enginePredictor(), name: "BLIND TEST", printMisses: false)
    #expect(s.top1 > 0)
}
