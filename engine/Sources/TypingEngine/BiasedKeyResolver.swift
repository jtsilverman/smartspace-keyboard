import Foundation

/// Stock-style probability-biased hit targets (Apple US 8,232,973 /
/// Gunawardana, Paek & Meek, IUI 2010): each key's touch score is a
/// geometric likelihood times a language prior, so the effective hit
/// region grows toward likely next letters while the visible caps never
/// change. Geometry dominates inside a cap; the prior decides edges and
/// gutters. Function zones ("__" ids) use a neutral prior.
public enum BiasedKeyResolver {

    /// Gaussian width of the touch model in points: how fast the geometric
    /// likelihood decays outside a cell. Small enough that cap-center taps
    /// are immune to any prior, big enough that a 1-2pt edge miss is not.
    static let sigma: Double = 6
    /// Tempering exponent on the prior: full geometry, tempered language.
    static let priorWeight: Double = 0.35
    public static func key(at point: Point, zones: [KeyZone], context: String) -> String? {
        // Geometry decides first. Function zones and non-letter keys keep
        // that verdict: the prior only arbitrates among letters, so it can
        // never hand a letter-adjacent tap to a function key or vice versa.
        guard let nearest = KeyZoneMap(keys: zones).key(at: point) else { return nil }
        guard isLetterZone(nearest) else { return nearest }

        let prev: Character = context.last.flatMap { $0.isLetter ? Character($0.lowercased()) : nil } ?? "^"
        var best: (id: String, score: Double)?
        for zone in zones where isLetterZone(zone.id) {
            let d2 = zone.frame.distanceSquared(to: point)
            guard d2 <= KeyZoneMap.tolerance * KeyZoneMap.tolerance else { continue }
            let geometry = exp(-d2 / (2 * sigma * sigma))
            let prior = CharBigram.probability(of: zone.id.first!, after: prev)
            let score = geometry * pow(prior, priorWeight)
            if score > (best?.score ?? -1) { best = (zone.id, score) }
        }
        return best?.id ?? nearest
    }

    private static func isLetterZone(_ id: String) -> Bool {
        id.count == 1 && id.first!.isLetter
    }
}
