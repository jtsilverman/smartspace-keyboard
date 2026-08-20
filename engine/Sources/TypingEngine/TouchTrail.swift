/// Where the thumb actually landed for each letter of the word being typed.
///
/// The probes say this is the signal stock corrects on (EVAL.md, 2026-08-20):
/// off-centre taps that produced a wrong letter were recovered 100% of the
/// time, and dead-centre taps on a wrong key only 47%. A centre press of the
/// wrong key is a deliberate keystroke to it. `KeyTouchSurface` resolves a
/// point to one letter and today the point dies there, so nothing downstream
/// can reconsider it.
public struct TouchTrail: Sendable {
    private let zones: [KeyZone]
    private var points: [Point] = []
    /// Cell width, used to report distances in key widths rather than points,
    /// so a trail recorded on one device class reads the same on another.
    private let pitch: Double

    public init(zones: [KeyZone]) {
        self.zones = zones
        let letters = zones.filter { $0.id.count == 1 && $0.id.first!.isLetter }
        self.pitch = letters.map(\.frame.width).min() ?? 1
    }

    public mutating func record(_ point: Point) { points.append(point) }

    /// Called at a word boundary: the trail describes one word.
    public mutating func reset() { points.removeAll() }

    public var count: Int { points.count }

    /// How far the tap at `index` sat from `letter`'s key centre, in key
    /// widths. Zero means dead centre on that letter. Nil when the trail does
    /// not cover the index, which is every path that never recorded touches.
    public func distance(at index: Int, to letter: Character) -> Double? {
        guard index >= 0, index < points.count else { return nil }
        let id = String(letter).lowercased()
        guard let zone = zones.first(where: { $0.id == id }) else { return nil }
        let point = points[index]
        let dx = (zone.frame.x + zone.frame.width / 2 - point.x) / pitch
        let dy = (zone.frame.y + zone.frame.height / 2 - point.y) / zone.frame.height
        return (dx * dx + dy * dy).squareRoot()
    }
}
