import Testing
import TypingEngine

// MARK: - BiasedKeyResolver: stock-style hit targets. Geometry decides caps;
// the letter-bigram prior decides edges and gutters (Apple US 8,232,973 /
// Gunawardana IUI 2010 shape: hit region grows toward likely letters,
// visuals unchanged).

/// Row-1 slice at measured metrics: e cell 82.4-121.9, w cell 42.9-82.4.
private let zones = [
    KeyZone(id: "w", frame: Rect(x: 42.9, y: 0, width: 39.5, height: 54)),
    KeyZone(id: "e", frame: Rect(x: 82.4, y: 0, width: 39.5, height: 54)),
    KeyZone(id: "__space", frame: Rect(x: 121.9, y: 54, width: 100, height: 54)),
]

@Test func capCenterIgnoresThePrior() {
    // Dead-center taps stay geometric: even a strong prior toward "e"
    // must not steal a tap from the middle of "w".
    let hit = BiasedKeyResolver.key(at: Point(x: 62.6, y: 27), zones: zones, context: "th")
    #expect(hit == "w")
}

@Test func cellEdgeFollowsThePrior() {
    // 1.5pt inside the w cell at the w/e boundary. After "th", English
    // overwhelmingly continues with "e"; stock resolves this tap to e.
    let hit = BiasedKeyResolver.key(at: Point(x: 80.9, y: 27), zones: zones, context: "th")
    #expect(hit == "e")
}

@Test func sameEdgeWithoutContextStaysGeometric() {
    // Same point, empty context: the word-start prior favors neither
    // letter strongly enough to overcome geometry.
    let hit = BiasedKeyResolver.key(at: Point(x: 80.9, y: 27), zones: zones, context: "")
    #expect(hit == "w")
}

@Test func functionZonesResolveGeometrically() {
    let hit = BiasedKeyResolver.key(at: Point(x: 170, y: 80), zones: zones, context: "th")
    #expect(hit == "__space")
}

@Test func farOutsideEveryZoneIsNil() {
    let hit = BiasedKeyResolver.key(at: Point(x: 300, y: 300), zones: zones, context: "th")
    #expect(hit == nil)
}
