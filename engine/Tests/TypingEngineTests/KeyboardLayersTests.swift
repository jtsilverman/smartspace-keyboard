import Testing
import TypingEngine

// MARK: - ShiftState v2: off -> one-shot -> caps lock, plus auto-shift

@Test func shiftDoubleTapWithinWindowEngagesCapsLock() {
    var shift = ShiftState()
    shift.tapShift(at: 10.0)
    shift.tapShift(at: 10.2)
    #expect(shift.mode == .capsLock)
    shift.didTypeLetter()
    #expect(shift.mode == .capsLock, "caps lock survives typing")
}

@Test func shiftSlowSecondTapDisarmsInsteadOfLocking() {
    var shift = ShiftState()
    shift.tapShift(at: 10.0)
    shift.tapShift(at: 11.0)
    #expect(shift.mode == .off)
}

@Test func tapWhileCapsLockedTurnsOff() {
    var shift = ShiftState()
    shift.tapShift(at: 1.0)
    shift.tapShift(at: 1.1)
    shift.tapShift(at: 5.0)
    #expect(shift.mode == .off)
}

@Test func oneShotStillConsumesOnLetter() {
    var shift = ShiftState()
    shift.tapShift(at: 3.0)
    #expect(shift.mode == .oneShot)
    #expect(shift.isShifted)
    shift.didTypeLetter()
    #expect(shift.mode == .off)
}

@Test func autoShiftArmsAtSentenceStartOnly() {
    var shift = ShiftState()
    shift.armAutoShift(for: "")
    #expect(shift.mode == .oneShot, "empty context starts a sentence")
    var mid = ShiftState()
    mid.armAutoShift(for: "on my way ")
    #expect(mid.mode == .off)
    var after = ShiftState()
    after.armAutoShift(for: "sounds good. ")
    #expect(after.mode == .oneShot)
}

@Test func autoShiftNeverDowngradesCapsLock() {
    var shift = ShiftState()
    shift.tapShift(at: 1.0)
    shift.tapShift(at: 1.1)
    shift.armAutoShift(for: "mid sentence ")
    #expect(shift.mode == .capsLock)
}

// MARK: - Layers

@Test func layerTogglesFollowStockKeyboardFlow() {
    var layer = KeyboardLayer.letters
    layer.toggle(.numbers)      // "123"
    #expect(layer == .numbers)
    layer.toggle(.symbols)      // "#+="
    #expect(layer == .symbols)
    layer.toggle(.numbers)      // "123" from symbols goes back to numbers
    #expect(layer == .numbers)
    layer.toggle(.letters)      // "ABC"
    #expect(layer == .letters)
}

@Test func numberAndSymbolRowsCoverStockCharacters() {
    let numbers = KeyboardLayout.numberRows.flatMap { $0 }
    #expect(numbers.count == 25)
    for digit in ["1", "9", "0", "-", "/", ":", ";", "(", ")", "$", "&", "@", "\"",
                  ".", ",", "?", "!", "'"] {
        #expect(numbers.contains(digit), "missing \(digit) on 123 layer")
    }
    let symbols = KeyboardLayout.symbolRows.flatMap { $0 }
    for mark in ["[", "]", "{", "}", "#", "%", "^", "*", "+", "=",
                 "_", "\\", "|", "~", "<", ">", "\u{20AC}", "\u{00A3}", "\u{00A5}",
                 "\u{2022}", ".", ",", "?", "!", "'"] {
        #expect(symbols.contains(mark), "missing \(mark) on #+= layer")
    }
}

@Test func longPressAlternatesExistForAccentedLetters() {
    #expect(KeyboardLayout.alternates["e"]?.contains("\u{00E9}") == true)  // é
    #expect(KeyboardLayout.alternates["n"]?.contains("\u{00F1}") == true)  // ñ
    #expect(KeyboardLayout.alternates["a"]?.contains("\u{00E0}") == true)  // à
    #expect(KeyboardLayout.alternates["c"]?.contains("\u{00E7}") == true)  // ç
    #expect(KeyboardLayout.alternates["$"]?.contains("\u{20AC}") == true)  // €
    #expect(KeyboardLayout.alternates["z"] == nil, "z has no stock alternates")
}

// MARK: - Return key label

@Test func returnKeyLabelFollowsHostFieldType() {
    #expect(ReturnKeyLabel.label(for: "search") == "Search")
    #expect(ReturnKeyLabel.label(for: "go") == "Go")
    #expect(ReturnKeyLabel.label(for: "send") == "Send")
    #expect(ReturnKeyLabel.label(for: "default") == "return")
    #expect(ReturnKeyLabel.label(for: "somethingUnknown") == "return")
}
