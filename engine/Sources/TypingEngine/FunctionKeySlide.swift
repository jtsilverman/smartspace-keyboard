/// Per-touch machine for the stock slide-from-a-function-key gesture:
/// touch shift or 123, slide to a character, release to commit it with
/// the modifier applied. The caller maps commitSlide to its meaning
/// (capital letter; symbol then back to letters) and passes nil for
/// zones that are neither the origin nor a character key.
public struct FunctionKeySlide {
    public enum Event: Equatable, Sendable {
        case activate(String)
        case highlight(String?)
        case commitTap(String)
        case commitSlide(from: String, to: String)
        case cancel(String)
        case none
    }

    private var touches: [Int: String] = [:]

    public init() {}

    public mutating func began(_ token: Int, function id: String) -> Event {
        touches[token] = id
        return .activate(id)
    }

    public mutating func moved(_ token: Int, key: String?) -> Event {
        guard touches[token] != nil else { return .none }
        return .highlight(key)
    }

    public mutating func ended(_ token: Int, key: String?) -> Event {
        guard let origin = touches.removeValue(forKey: token) else { return .none }
        guard let key else { return .cancel(origin) }
        return key == origin ? .commitTap(origin) : .commitSlide(from: origin, to: key)
    }

    public mutating func cancelled(_ token: Int) -> Event {
        guard let origin = touches.removeValue(forKey: token) else { return .none }
        return .cancel(origin)
    }
}
