/// Decides what each held-delete repeat tick removes: single characters
/// first, whole whitespace-delimited chunks after a sustained hold, like
/// the stock keyboard. Pure decision; the controller owns the timer.
public struct BackspaceRepeater {
    public enum Action: Equatable {
        case characters(Int)
        case word(Int)
    }

    /// Single-character ticks before whole-word deletes begin.
    public static let characterTicks = 20

    private var ticks = 0

    public init() {}

    public mutating func tick(before context: String) -> Action {
        ticks += 1
        guard ticks > Self.characterTicks else { return .characters(1) }
        return .word(Self.chunkLength(before: context))
    }

    public mutating func reset() {
        ticks = 0
    }

    /// Trailing whitespace run plus the non-whitespace run behind it.
    /// A whitespace run holding a newline deletes alone, so the hold
    /// stops at each line boundary it unmakes.
    private static func chunkLength(before context: String) -> Int {
        var rest = context[...]
        var count = 0
        var sawNewline = false
        while let c = rest.last, c.isWhitespace {
            if c.isNewline { sawNewline = true }
            count += 1
            rest = rest.dropLast()
        }
        if sawNewline { return count }
        while let c = rest.last, !c.isWhitespace {
            count += 1
            rest = rest.dropLast()
        }
        return count
    }
}
