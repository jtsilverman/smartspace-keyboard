import XCTest

/// Unit 2 of specs/autocorrect-parity.md, driven on the real keyboard: the
/// same five letters correct or not depending on where the thumb landed.
/// The engine tests prove the rule; this proves the tap points survive
/// KeyTouchSurface and reach the corrector in the running extension.
final class TouchSlipTests: XCTestCase {

    func testDeadCentreTapsAreTakenAsTyped() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)
        clear(app, field)
        type(app, "mokey", leaning: nil)
        keyButton(app, "space").tap()
        assertFieldValue(field, "Mokey ", "a centre press of k is a deliberate k")
    }

    func testAThumbThatReachedTowardTheOtherKeyCorrects() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)
        clear(app, field)
        type(app, "mokey", leaning: (slot: 2, toward: "n", fraction: 0.8))
        keyButton(app, "space").tap()
        assertFieldValue(field, "Money ", "the thumb was most of the way to n")
    }

    /// Taps each letter at its cap centre, except the leaning slot, which taps
    /// a point most of the way toward another key.
    private func type(_ app: XCUIApplication, _ word: String,
                      leaning: (slot: Int, toward: Character, fraction: Double)?) {
        for (index, letter) in word.enumerated() {
            let from = centre(app, letter)
            var point = from
            if let leaning, leaning.slot == index {
                let to = centre(app, leaning.toward)
                point = CGPoint(x: from.x + (to.x - from.x) * leaning.fraction,
                                y: from.y + (to.y - from.y) * leaning.fraction)
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: point.x, dy: point.y)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }

    /// Key titles flip case with the shift state, so the frame is read from
    /// whichever case is on screen.
    private func centre(_ app: XCUIApplication, _ letter: Character) -> CGPoint {
        let lower = keyButton(app, String(letter))
        let key = lower.exists ? lower : keyButton(app, String(letter).uppercased())
        XCTAssertTrue(key.waitForExistence(timeout: 3), "key \(letter) never appeared")
        let frame = key.frame
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func clear(_ app: XCUIApplication, _ field: XCUIElement) {
        let deadline = Date().addingTimeInterval(30)
        while fieldText(field) != "", Date() < deadline {
            app.buttons["⌫"].press(forDuration: 2.0)
        }
        XCTAssertEqual(fieldText(field), "", "field never cleared")
    }
}
