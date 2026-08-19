import XCTest

/// Measurement harness, not a regression test: walks x in 1pt steps across
/// the q|w handoff and prints the character each point types, so a dead
/// band shows up as a run of "-" instead of a q-to-w switch.
final class EdgeSweepTests: XCTestCase {

    func testSweepStock() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusStock(app)
        sweep(app, field: field, side: "stock") { app.keys[$0] }
    }

    func testSweepSmartSpace() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)
        sweep(app, field: field, side: "smartspace") { app.buttons[$0] }
    }

    private func sweep(_ app: XCUIApplication, field: XCUIElement, side: String,
                       key: (String) -> XCUIElement) {
        let q = key("q").exists ? key("q") : key("Q")
        XCTAssertTrue(q.waitForExistence(timeout: 5))
        let y = q.frame.midY
        print("SWEEP \(side) qFrame=\(q.frame)")
        // Seed so the field is never empty; an empty field reports its
        // placeholder as .value.
        for _ in 0..<3 {
            let h = key("h").exists ? key("h") : key("H")
            h.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        for step in 0...50 {
            let x = 28.0 + Double(step)
            let before = fieldText(field)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: CGFloat(x), dy: y)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            let after = fieldText(field)
            let typed = after.count == before.count + 1 ? String(after.last!) : "-"
            print("SWEEP \(side) x=\(x) typed=\(typed)")
            if typed != "-" {
                for candidate in [app.keys["delete"], app.buttons["delete"]] where candidate.exists {
                    candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                    break
                }
            }
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
