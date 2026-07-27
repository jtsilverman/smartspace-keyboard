import Testing
import TypingEngine

@Test func qwertyLetterRowsMatchStandardLayout() {
    #expect(KeyboardLayout.letterRows == [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ])
}

@Test func qwertyCoversAllTwentySixLettersExactlyOnce() {
    let letters = KeyboardLayout.letterRows.flatMap { $0 }
    #expect(letters.count == 26)
    #expect(Set(letters).count == 26)
    #expect(letters.allSatisfy { $0.count == 1 && $0 == $0.lowercased() })
}

@Test func shiftStartsLowercase() {
    let shift = ShiftState()
    #expect(!shift.isShifted)
}

@Test func shiftTapArmsOneShot() {
    var shift = ShiftState()
    shift.tapShift()
    #expect(shift.isShifted)
}

@Test func typingALetterConsumesTheOneShot() {
    var shift = ShiftState()
    shift.tapShift()
    shift.didTypeLetter()
    #expect(!shift.isShifted)
}

@Test func secondShiftTapDisarms() {
    var shift = ShiftState()
    shift.tapShift()
    shift.tapShift()
    #expect(!shift.isShifted)
}

@Test func typingWhileLowercaseStaysLowercase() {
    var shift = ShiftState()
    shift.didTypeLetter()
    #expect(!shift.isShifted)
}
