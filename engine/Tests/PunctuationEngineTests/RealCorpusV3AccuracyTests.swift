import Testing

/// Real-SMS v3 (adjudicated relabel). Same charter as v2.1: dev misses may be
/// studied; the test half reports aggregate numbers only.
@Test func realV3DevAccuracyReport() {
    #expect(realV3Dev.count == 319)
    let s = evalScore(realV3Dev, predict: enginePredictor(), name: "REAL-V3 DEV", printMisses: true)
    #expect(s.top1 > 0)
}

@Test func realV3TestAccuracyReport() {
    #expect(realV3Test.count == 319)
    let s = evalScore(realV3Test, predict: enginePredictor(), name: "REAL-V3 TEST", printMisses: false)
    #expect(s.top1 > 0)
}
