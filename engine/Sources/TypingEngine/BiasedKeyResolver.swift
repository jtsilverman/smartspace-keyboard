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

    /// The prior is OFF. Boundaries re-probed on the stock keyboard
    /// (iPhone 17, 2026-08-18, StockBoundaryTests) step by exactly 39.50pt
    /// across all 23 letter pairs, with no variation by pair: stock's hit
    /// map is uniform geometry, not a language model, under a fixed
    /// preceding letter. Scoring ours against those measurements: pure
    /// geometry lands 2.78pt mean / 2.98pt worst, the shipped prior 5.16 /
    /// 12.63. Our bigram table pulls against stock's uniform grid, so
    /// biasing quadruples the worst-case miss and costs Jake the fixed key
    /// areas his muscle memory depends on. The scoring stays here for the
    /// day a model trained on his own typing replaces the table (Jake,
    /// 2026-08-18).
    public static let priorIsEnabled = false
    public static func key(at point: Point, zones: [KeyZone], context: String) -> String? {
        guard priorIsEnabled else { return KeyZoneMap(keys: zones).key(at: point) }
        return key(at: point, zones: zones, context: context,
                   sigma: sigma, priorWeight: priorWeight)
    }

    /// The knobs are parameters so a fit can search them without touching
    /// shared state (Swift 6 forbids mutable statics).
    public static func key(at point: Point, zones: [KeyZone], context: String,
                           sigma: Double, priorWeight: Double) -> String? {
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
