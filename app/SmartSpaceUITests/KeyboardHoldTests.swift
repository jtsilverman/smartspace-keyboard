import XCTest

/// Measurement harness, not a regression test (stock-parity AC 1): parks
/// the stock keyboard on screen, then the SmartSpace keyboard, holding each
/// long enough for the host to capture `simctl io screenshot`. Pixel
/// analysis of those shots gives the real visible key-cap geometry that the
/// accessibility frames (touch cells) do not expose.
final class KeyboardHoldTests: XCTestCase {

    /// SmartSpace only, via the shared helper that every passing suite
    /// uses; the stock shot is already measured and does not need retaking.
    func testHoldSmartSpaceForCapture() throws {
        let app = XCUIApplication()
        app.launch()
        _ = focusSmartSpaceKeyboard(app)
        print("HOLD-PHASE smartspace ready")
        RunLoop.current.run(until: Date().addingTimeInterval(25))
    }

    func testHoldStockThenSmartSpaceForCapture() throws {
        let app = XCUIApplication()
        app.launch()
        let field = app.textFields["Type here to test the keyboard"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()

        // Phase 1: stock keyboard (exposes XCUIElement keys), hold 20s.
        var hops = 0
        while !app.keys["q"].waitForExistence(timeout: 2) && !app.keys["Q"].waitForExistence(timeout: 1) {
            hops += 1
            guard hops < 8 else { XCTFail("stock never appeared"); return }
            if app.buttons["Next keyboard"].exists {
                app.buttons["Next keyboard"].tap()
            } else if app.keys["Next keyboard"].exists {
                app.keys["Next keyboard"].tap()
            } else if app.buttons["emoji"].exists {
                app.buttons["emoji"].tap()
            }
        }
        print("HOLD-PHASE stock ready")
        RunLoop.current.run(until: Date().addingTimeInterval(20))

        // Phase 2: hop to SmartSpace (the only keyboard with a "space"
        // UIButton), hold 20s.
        hops = 0
        while !app.buttons["space"].waitForExistence(timeout: 2) {
            hops += 1
            guard hops < 8 else { XCTFail("SmartSpace never appeared"); return }
            if app.buttons["Next keyboard"].exists {
                app.buttons["Next keyboard"].tap()
            } else if app.keys["Next keyboard"].exists {
                app.keys["Next keyboard"].tap()
            }
        }
        print("HOLD-PHASE smartspace ready")
        RunLoop.current.run(until: Date().addingTimeInterval(20))
    }
}
