/// Tracks the one auto-inserted trailing space that sentence punctuation
/// can absorb, like stock: "hello " + "," becomes "hello,". The keyboard
/// arms it after inserting a space on the user's behalf and asks it how
/// many characters to delete before the next typed mark.
public struct TrailingAutoSpace {
    private var isArmed = false

    public init() {}

    /// The keyboard inserted a space on the user's behalf.
    public mutating func arm() {
        isArmed = true
    }

    /// The document tail changed some other way (backspace, cursor move).
    public mutating func disarm() {
        isArmed = false
    }

    /// Characters to delete before inserting `char`. 1 eats the armed
    /// auto-space. Every call consumes the arm.
    public mutating func deletions(forTyping char: Character, context: String) -> Int {
        0
    }
}
