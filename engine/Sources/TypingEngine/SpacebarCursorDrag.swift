/// Turns horizontal spacebar-drag travel into cursor-step deltas, one step
/// per `stepWidth` points, truncating toward zero so a sub-step wobble in
/// either direction moves nothing. Pure math -- the keyboard supplies touch
/// x-coordinates and applies the deltas via adjustTextPosition.
public struct SpacebarCursorDrag: Sendable {
    /// Horizontal points of travel per one cursor step. Public so UI tests
    /// derive exact drag distances from it.
    public static let stepWidth: Double = 9.0

    private var origin: Double = 0
    private var emitted = 0

    public init() {}

    public mutating func began(at x: Double) {
        origin = x
        emitted = 0
    }

    /// The delta to apply NOW (total truncated steps minus already emitted).
    public mutating func moved(to x: Double) -> Int {
        let total = Int((x - origin) / Self.stepWidth)
        defer { emitted = total }
        return total - emitted
    }
}
