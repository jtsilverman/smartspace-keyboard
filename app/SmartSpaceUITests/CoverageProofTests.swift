import XCTest

/// Proof harness for Jake's invariant: a key owns a fixed area, and no
/// point between two caps is dead. Walks the full width of one letter row
/// in 1pt steps and prints the character each point types, once against
/// the stock keyboard and once against SmartSpace, so the two maps can be
/// diffed point by point. One test per row per side: a single test that
/// swept all three rows ran past the harness time cap.
final class CoverageProofTests: XCTestCase {

    /// Sweep ranges, in points, inside both keyboards' letter cells on a
    /// 402pt-wide screen. Stock's leftmost cell starts at 4.667 and ours at
    /// 3.67, so the range starts inside both.
    private static let ranges: [(row: Int, from: Double, through: Double)] = [
        (0, 5, 397), (1, 25, 377), (2, 64, 337),
    ]
    private static let seed = "hhh"

    func testStockRow0() throws { try sweepStock(0) }
    func testStockRow1() throws { try sweepStock(1) }
    func testStockRow2() throws { try sweepStock(2) }
    func testSmartSpaceRow0() throws { try sweepSmartSpace(0) }
    func testSmartSpaceRow1() throws { try sweepSmartSpace(1) }
    func testSmartSpaceRow2() throws { try sweepSmartSpace(2) }

    private func sweepStock(_ row: Int) throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusStock(app)
        sweep(app, field: field, side: "stock", row: row) { app.keys[$0] }
    }

    private func sweepSmartSpace(_ row: Int) throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)
        sweep(app, field: field, side: "smartspace", row: row) { app.buttons[$0] }
    }

    /// The anchor key gives the row's y. Its own x is never used, so a cap
    /// frame and a cell frame anchor the same row.
    private static let anchors = ["q", "a", "z"]

    private func sweep(_ app: XCUIApplication, field: XCUIElement, side: String,
                       row: Int, key: (String) -> XCUIElement) {
        let name = Self.anchors[row]
        let anchor = key(name).exists ? key(name) : key(name.uppercased())
        XCTAssertTrue(anchor.waitForExistence(timeout: 5), "row \(row) never appeared")
        let y = anchor.frame.midY
        seed(app, field: field, key: key)

        let range = Self.ranges[row]
        var x = range.from
        while x <= range.through {
            print("COV \(side) row=\(row) x=\(x) typed=\(type(app, field: field, x: x, y: y))")
            x += 1
        }
    }

    /// The field must never be empty: an empty field reports its
    /// placeholder as .value, and auto-shift arms on an empty field.
    private func seed(_ app: XCUIApplication, field: XCUIElement, key: (String) -> XCUIElement) {
        for _ in 0..<40 {
            if fieldText(field).isEmpty { break }
            deleteOne(app)
        }
        for _ in Self.seed {
            let h = key("h").exists ? key("h") : key("H")
            h.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertEqual(fieldText(field).lowercased(), Self.seed, "seed never landed")
    }

    /// One tap, the character it produced, and a delete so the next point
    /// starts from the seed. "-" means the point typed nothing.
    private func type(_ app: XCUIApplication, field: XCUIElement,
                      x: Double, y: CGFloat) -> String {
        let before = fieldText(field)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: CGFloat(x), dy: y)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        let after = fieldText(field)
        guard after.count == before.count + 1, let last = after.last else { return "-" }
        deleteOne(app)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        return String(last).lowercased()
    }

    private func deleteOne(_ app: XCUIApplication) {
        for candidate in [app.keys["delete"], app.buttons["delete"], app.keys["Delete"]]
        where candidate.exists {
            candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            return
        }
    }

    private func focusStock(_ app: XCUIApplication) -> XCUIElement {
        let field = app.textFields[XCTestCase.practiceFieldPlaceholder]
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
