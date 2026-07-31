/// Stock iOS double-space-period, used when smart double-space is OFF: a
/// second space within the window swaps the just-typed space for ". ", but
/// only after a word character. No cycling -- firing closes the window, so
/// a third space is plain. Pure state; the keyboard supplies timestamps and
/// the word-char check, and performs the text edits.
public struct StockDoubleSpace: Sendable {
    public enum Decision: Equatable, Sendable {
        /// Insert a plain space.
        case insertSpace
        /// Replace the just-typed space with ". ".
        case insertPeriod
    }

    private var lastSpaceTap: Double?

    public init() {}

    public mutating func spaceTapped(at time: Double, afterWordChar: Bool) -> Decision {
        if let last = lastSpaceTap, time - last <= SmartSpaceBar.doubleSpaceWindow, afterWordChar {
            lastSpaceTap = nil
            return .insertPeriod
        }
        lastSpaceTap = time
        return .insertSpace
    }

    /// Every non-space key closes the double-tap window.
    public mutating func nonSpaceKey() {
        lastSpaceTap = nil
    }
}
