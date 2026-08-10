/// Stock-style probability-biased hit targets (Apple US 8,232,973 /
/// Gunawardana, Paek & Meek, IUI 2010): each key's touch score is a
/// geometric likelihood times a language prior, so the effective hit
/// region grows toward likely next letters while the visible caps never
/// change. Geometry dominates inside a cap; the prior decides edges and
/// gutters. Function zones ("__" ids) use a neutral prior.
public enum BiasedKeyResolver {

    /// Stub: behavior lands in GREEN. Falls back to pure geometry.
    public static func key(at point: Point, zones: [KeyZone], context: String) -> String? {
        KeyZoneMap(keys: zones).key(at: point)
    }
}
