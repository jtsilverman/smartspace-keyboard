import PunctuationEngine

/// The hero-feature state machine: turns raw space-bar taps into decisions.
/// First tap inserts a space; a second within the window swaps that space for
/// the engine's top candidate; further taps cycle candidates in place; any
/// other key ends the cycle. Pure logic -- the keyboard supplies timestamps
/// and a candidates closure, and performs the text edits.
public struct SmartSpaceBar: Sendable {
    public enum Decision: Equatable, Sendable {
        /// Insert a plain space.
        case insertSpace
        /// Replace the just-typed space with "<mark> ".
        case insertMark(Candidate)
        /// Replace the current "<replacing> " with "<mark> ". The keyboard
        /// verifies the text still ends with the old mark before deleting --
        /// the cursor may have moved between taps.
        case replaceMark(Candidate, replacing: Candidate)
    }

    public static let doubleSpaceWindow: Double = 0.3

    private var lastSpaceTap: Double?
    private var cycle: CycleState?

    public init() {}

    public mutating func spaceTapped(at time: Double,
                                     candidates: () -> [Candidate]) -> Decision {
        if var active = cycle {
            let previous = active.current
            let next = active.advance()
            cycle = active
            return .replaceMark(next, replacing: previous)
        }
        if let last = lastSpaceTap, time - last <= Self.doubleSpaceWindow,
           let started = CycleState(candidates: candidates()) {
            cycle = started
            lastSpaceTap = nil
            return .insertMark(started.current)
        }
        lastSpaceTap = time
        return .insertSpace
    }

    /// Every non-space key ends any active cycle and the double-tap chance.
    public mutating func nonSpaceKey() {
        cycle = nil
        lastSpaceTap = nil
    }
}
