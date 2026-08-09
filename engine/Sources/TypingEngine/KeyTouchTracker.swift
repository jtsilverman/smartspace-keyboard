/// Per-touch decision machine for the keyboard's touch layer (stock-parity:
/// no tap is ever eaten). The UIKit surface forwards raw touch events with
/// resolved key ids; this tracker owns what each event means. Hold semantics
/// mirror stock: a held key without alternates still types on release; a
/// held key with alternates enters slide-select and the release commits the
/// highlighted option, defaulting to the base key.

public struct KeyTouchTracker {

    public enum Event: Equatable, Sendable {
        case keyDown(String)
        case retarget(from: String, to: String)
        case exitKey(String)
        case commit(String)
        case showAlternates(String)
        case moveAlternate(x: Double)
        case commitAlternate(base: String, x: Double)
        case none
    }

    private enum Phase {
        case tracking(String)
        case alternates(String)
    }

    private var touches: [Int: Phase] = [:]

    public init() {}

    /// Stub: behavior lands in GREEN.
    public mutating func began(_ token: Int, key: String?) -> Event { .none }
    public mutating func moved(_ token: Int, key: String?, x: Double) -> Event { .none }
    public mutating func holdFired(_ token: Int, hasAlternates: Bool) -> Event { .none }
    public mutating func ended(_ token: Int, x: Double) -> Event { .none }
    public mutating func cancelled(_ token: Int) -> Event { .none }
}
