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

    public mutating func began(_ token: Int, key: String?) -> Event {
        guard let key else { return .none }
        touches[token] = .tracking(key)
        return .keyDown(key)
    }

    public mutating func moved(_ token: Int, key: String?, x: Double) -> Event {
        switch touches[token] {
        case .alternates:
            return .moveAlternate(x: x)
        case .tracking(let current):
            guard key != current else { return .none }
            if let key {
                touches[token] = .tracking(key)
                return .retarget(from: current, to: key)
            }
            // Slid onto a function key or off the surface: stock cancels.
            touches[token] = nil
            return .exitKey(current)
        case nil:
            return .none
        }
    }

    /// The hold timer fired. Without alternates nothing changes: the touch
    /// keeps tracking and still types on release. With alternates the touch
    /// enters slide-select.
    public mutating func holdFired(_ token: Int, hasAlternates: Bool) -> Event {
        guard case .tracking(let key) = touches[token], hasAlternates else { return .none }
        touches[token] = .alternates(key)
        return .showAlternates(key)
    }

    public mutating func ended(_ token: Int, x: Double) -> Event {
        switch touches.removeValue(forKey: token) {
        case .tracking(let key): return .commit(key)
        case .alternates(let base): return .commitAlternate(base: base, x: x)
        case nil: return .none
        }
    }

    public mutating func cancelled(_ token: Int) -> Event {
        touches[token] = nil
        return .none
    }

    public var isIdle: Bool { touches.isEmpty }
}
