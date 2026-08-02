import Testing
import TypingEngine

// Stock double-space-period fallback for smart-double-space OFF (spec
// host-app-settings, Jake's locked decision 1): second space within the
// window swaps the space for ". " only when the space follows a word
// character; no cycling -- the third space is plain.

@Test func doubleSpaceAfterWordCharInsertsPeriod() {
    var bar = StockDoubleSpace()
    #expect(bar.spaceTapped(at: 1.0, afterWordChar: true) == .insertSpace)
    #expect(bar.spaceTapped(at: 1.2, afterWordChar: true) == .insertPeriod)
}

@Test func doubleSpaceAfterNonWordCharStaysPlain() {
    var bar = StockDoubleSpace()
    _ = bar.spaceTapped(at: 1.0, afterWordChar: false)
    #expect(bar.spaceTapped(at: 1.2, afterWordChar: false) == .insertSpace)
}

@Test func stockSlowSecondSpaceStaysPlain() {
    var bar = StockDoubleSpace()
    _ = bar.spaceTapped(at: 1.0, afterWordChar: true)
    #expect(bar.spaceTapped(at: 2.0, afterWordChar: true) == .insertSpace)
}

@Test func thirdSpaceAfterPeriodIsPlainNoCycling() {
    var bar = StockDoubleSpace()
    _ = bar.spaceTapped(at: 1.0, afterWordChar: true)
    _ = bar.spaceTapped(at: 1.2, afterWordChar: true)
    // Fast third tap: the fired period closed the window, and "." is not a
    // word char anyway -- plain space, never a second period.
    #expect(bar.spaceTapped(at: 1.3, afterWordChar: false) == .insertSpace)
}

@Test func nonSpaceKeyClosesWindow() {
    var bar = StockDoubleSpace()
    _ = bar.spaceTapped(at: 1.0, afterWordChar: true)
    bar.nonSpaceKey()
    #expect(bar.spaceTapped(at: 1.1, afterWordChar: true) == .insertSpace)
}

@Test func windowReopensAfterMissedChance() {
    var bar = StockDoubleSpace()
    _ = bar.spaceTapped(at: 1.0, afterWordChar: true)
    _ = bar.spaceTapped(at: 2.0, afterWordChar: true)   // too slow, plain
    #expect(bar.spaceTapped(at: 2.1, afterWordChar: true) == .insertPeriod)
}
