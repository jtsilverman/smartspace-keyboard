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
        return .characters(1)
    }

    public mutating func reset() {
        ticks = 0
    }
}
