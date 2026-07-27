/// The QWERTY letter grid the keyboard extension renders. Data only; the
/// extension owns buttons and sizing, this owns which letters exist and where.
public enum KeyboardLayout {
    public static let letterRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]
}

/// One-shot shift: a tap arms uppercase for exactly the next letter.
/// Caps lock and auto-shift arrive in WORKPLAN 3.2.
public struct ShiftState: Sendable {
    public private(set) var isShifted = false

    public init() {}

    public mutating func tapShift() {
        isShifted.toggle()
    }

    public mutating func didTypeLetter() {
        isShifted = false
    }
}
