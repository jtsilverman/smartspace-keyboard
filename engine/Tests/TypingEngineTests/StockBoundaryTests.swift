import Testing
import Foundation
import TypingEngine

// Where stock hands a tap from one letter to the next, probed on the real
// stock keyboard by tap-bisection (iPhone 17, iOS 26.3.1, 2026-08-18,
// eval/parity + BoundaryProbeTests). Apple biases these boundaries with its
// own language model, so they never sit exactly on the cell edges; the gap
// below is what a fixed-area keyboard can reach.
private let measuredStock: [(String, String, Double)] = [
    ("q", "w", 42.39), ("w", "e", 83.43), ("e", "r", 119.23), ("r", "t", 161.19),
    ("t", "y", 197.92), ("y", "u", 246.06), ("u", "i", 272.60), ("i", "o", 325.98),
    ("o", "p", 356.23),
    ("a", "s", 59.89), ("s", "d", 94.76), ("d", "f", 147.84), ("f", "g", 178.39),
    ("g", "h", 217.89), ("h", "j", 252.46), ("j", "k", 304.92), ("k", "l", 336.39),
    ("z", "x", 99.39), ("x", "c", 138.89), ("c", "v", 180.86), ("v", "b", 217.89),
    ("b", "n", 257.39), ("n", "m", 296.89),
]

private func letterZones(width: Double) -> [KeyZone] {
    StockLayoutMetrics.cells(width: width, plane: KeyboardLayout.letterRows)
        .map { KeyZone(id: $0.id, frame: $0.frame) }
}

/// Bisects between two key centres for the x where the resolver switches.
private func boundary(_ a: String, _ b: String, zones: [KeyZone]) -> Double? {
    guard let ca = zones.first(where: { $0.id == a })?.frame,
          let cb = zones.first(where: { $0.id == b })?.frame else { return nil }
    let y = ca.y + ca.height / 2
    var low = ca.x + ca.width / 2, high = cb.x + cb.width / 2
    while high - low > 0.05 {
        let mid = (low + high) / 2
        if BiasedKeyResolver.key(at: Point(x: mid, y: y), zones: zones, context: "") == a {
            low = mid
        } else {
            high = mid
        }
    }
    return (low + high) / 2
}

@Test func everyBoundarySitsWithinEightPointsOfStock() {
    let zones = letterZones(width: 402)
    for (a, b, want) in measuredStock {
        let got = try! #require(boundary(a, b, zones: zones))
        #expect(abs(got - want) <= 8,
                "\(a)|\(b): ours \(got), stock \(want)")
    }
}

@Test func theMeanBoundaryErrorStaysUnderFourPoints() {
    let zones = letterZones(width: 402)
    let errors = measuredStock.compactMap { a, b, want in
        boundary(a, b, zones: zones).map { abs($0 - want) }
    }
    #expect(errors.count == measuredStock.count)
    #expect(errors.reduce(0, +) / Double(errors.count) <= 4)
}

// Jake's invariant: a key owns a fixed area. Every point between two cap
// centres resolves to one letter or the other, and the switch happens once.
@Test func everyPointBetweenTwoCapsBelongsToOneOfThem() {
    let zones = letterZones(width: 402)
    for (a, b, _) in measuredStock {
        guard let ca = zones.first(where: { $0.id == a })?.frame,
              let cb = zones.first(where: { $0.id == b })?.frame else { continue }
        let y = ca.y + ca.height / 2
        var switches = 0
        var previous = a
        var x = ca.x + ca.width / 2
        while x <= cb.x + cb.width / 2 {
            let hit = BiasedKeyResolver.key(at: Point(x: x, y: y), zones: zones, context: "")
            #expect(hit == a || hit == b, "point \(x) resolved to \(hit ?? "nothing")")
            if let hit, hit != previous { switches += 1; previous = hit }
            x += 0.33
        }
        #expect(switches == 1, "\(a)|\(b) switched \(switches) times")
    }
}
