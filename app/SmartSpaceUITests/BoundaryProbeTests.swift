import XCTest

/// Measurement harness for the touch map, not a regression test: taps the
/// keyboard at computed points and reads what each point types, bisecting
/// between neighbouring key centres to find the exact boundary. Runs once
/// against the stock keyboard and once against SmartSpace, so the two maps
/// can be diffed in points. The field stays a single word, so autocorrect
/// never fires and every tap is one character.
final class BoundaryProbeTests: XCTestCase {

    private let rows = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]

    func testProbeStockBoundaries() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusStock(app)
        probe(app, field: field, side: "stock") { app.keys[$0] }
    }

    func testProbeSmartSpaceBoundaries() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)
        probe(app, field: field, side: "smartspace") { app.buttons[$0] }
    }

    /// Walks each row, bisecting the gap between neighbouring key centres
    /// until the boundary is known to a third of a point (one device pixel
    /// at 3x). Prints one line per boundary for the host-side diff.
    private func probe(_ app: XCUIApplication, field: XCUIElement, side: String,
                       key: (String) -> XCUIElement) {
        for (index, row) in rows.enumerated() {
            guard let first = frame(key, row[0]) else {
                print("PROBE \(side) row=\(index) SKIP no frame")
                continue
            }
            let y = first.midY
            for pair in zip(row, row.dropFirst()) {
                guard let left = frame(key, pair.0), let right = frame(key, pair.1) else { continue }
                var low = left.midX, high = right.midX
                while high - low > 0.33 {
                    let mid = (low + high) / 2
                    let typed = type(app, field: field, x: mid, y: y)
                    if typed == pair.0.lowercased() { low = mid } else { high = mid }
                }
                print("PROBE \(side) row=\(index) pair=\(pair.0)|\(pair.1) boundary=\(String(format: "%.2f", (low + high) / 2))")
            }
        }
    }

    private func frame(_ key: (String) -> XCUIElement, _ id: String) -> CGRect? {
        let lower = key(id), upper = key(id.uppercased())
        if lower.exists { return lower.frame }
        if upper.exists { return upper.frame }
        return nil
    }

    /// Taps one absolute point, returns the character it produced (empty when
    /// the point typed nothing), and clears it so the next probe starts from
    /// the same state.
    private func type(_ app: XCUIApplication, field: XCUIElement,
                      x: CGFloat, y: CGFloat) -> String {
        let before = (field.value as? String) ?? ""
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: x, dy: y)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        let after = (field.value as? String) ?? ""
        guard after.count > before.count, let last = after.last else { return "" }
        deleteOne(app)
        return String(last).lowercased()
    }

    private func deleteOne(_ app: XCUIApplication) {
        for candidate in [app.keys["delete"], app.buttons["delete"], app.keys["Delete"]]
        where candidate.exists {
            candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            return
        }
    }

    private func focusStock(_ app: XCUIApplication) -> XCUIElement {
        let field = app.textFields["Type here to test the keyboard"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        for _ in 0..<10 {
            if app.keys["q"].waitForExistence(timeout: 2)
                || app.keys["Q"].waitForExistence(timeout: 1) { return field }
            for hop in [app.buttons["Next keyboard"], app.keys["Next keyboard"], app.buttons["emoji"]]
            where hop.exists {
                hop.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                break
            }
        }
        XCTFail("stock keyboard never appeared")
        return field
    }
}
