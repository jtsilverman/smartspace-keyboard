/// Pure geometry for stock-feel touch resolution (stock-parity AC 2): a
/// touch anywhere on the keyboard surface resolves to the nearest key, so
/// gutters and key edges never eat fast, sloppy taps. Platform-free types;
/// the keyboard converts from UIKit frames.

public struct Point: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Rect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Squared distance from a point to this rect; 0 when inside.
    func distanceSquared(to p: Point) -> Double {
        let dx = max(x - p.x, 0, p.x - (x + width))
        let dy = max(y - p.y, 0, p.y - (y + height))
        return dx * dx + dy * dy
    }
}

public struct KeyZone: Equatable, Sendable {
    public let id: String
    public let frame: Rect
    public init(id: String, frame: Rect) {
        self.id = id
        self.frame = frame
    }
}

public struct KeyZoneMap: Sendable {
    /// How far outside a key's frame a touch may land and still resolve to
    /// it. Covers gutters (split to the nearest neighbor) and screen-edge
    /// bezel touches, like stock.
    public static let tolerance: Double = 10

    private let keys: [KeyZone]

    public init(keys: [KeyZone]) {
        self.keys = keys
    }

    /// The nearest key within tolerance, or nil for dead space.
    public func key(at point: Point) -> String? {
        let best = keys.min { lhs, rhs in
            lhs.frame.distanceSquared(to: point) < rhs.frame.distanceSquared(to: point)
        }
        guard let best,
              best.frame.distanceSquared(to: point) <= Self.tolerance * Self.tolerance
        else { return nil }
        return best.id
    }
}
