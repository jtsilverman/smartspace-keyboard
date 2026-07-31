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
