import Testing
import TypingEngine

// Stock-parity AC 2: every touch inside the keyboard surface resolves to the
// nearest key -- gutters between keys belong to their neighbors, so sloppy
// fast taps never fall into dead space. Pure geometry, device-independent.

private func map() -> KeyZoneMap {
    // Two rows of two 40x50 keys with 8pt gutters, rows 8pt apart.
    KeyZoneMap(keys: [
        KeyZone(id: "q", frame: Rect(x: 0, y: 0, width: 40, height: 50)),
        KeyZone(id: "w", frame: Rect(x: 48, y: 0, width: 40, height: 50)),
        KeyZone(id: "a", frame: Rect(x: 0, y: 58, width: 40, height: 50)),
        KeyZone(id: "s", frame: Rect(x: 48, y: 58, width: 40, height: 50)),
    ])
}

@Test func touchInsideAKeyHitsThatKey() {
    #expect(map().key(at: Point(x: 20, y: 25)) == "q")
    #expect(map().key(at: Point(x: 70, y: 25)) == "w")
}

@Test func touchInTheGutterHitsTheNearestKey() {
    // 44 is the midpoint between q (ends 40) and w (starts 48).
    #expect(map().key(at: Point(x: 42, y: 25)) == "q")
    #expect(map().key(at: Point(x: 46, y: 25)) == "w")
}

@Test func touchInTheRowGapHitsTheNearestRow() {
    #expect(map().key(at: Point(x: 20, y: 52)) == "q")
    #expect(map().key(at: Point(x: 20, y: 57)) == "a")
}

@Test func touchFarOutsideResolvesNil() {
    // Beyond the tolerance margin around the whole surface: no key.
    #expect(map().key(at: Point(x: 300, y: 300)) == nil)
}

@Test func touchJustOutsideTheEdgeStillHitsTheEdgeKey() {
    // Stock keeps edge keys reachable from the screen bezel.
    #expect(map().key(at: Point(x: -3, y: 25)) == "q")
    #expect(map().key(at: Point(x: 20, y: -3)) == "q")
}
