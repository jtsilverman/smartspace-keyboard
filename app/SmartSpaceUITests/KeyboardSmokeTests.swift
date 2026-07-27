import XCTest

/// Live smoke test for the 3.1 scaffold: drives the REAL keyboard extension in
/// the simulator and asserts what lands in the text field. Requires the
/// SmartSpace keyboard to be enabled on the target device (CI/dev: written into
/// com.apple.Preferences AppleKeyboards before the run).
final class KeyboardSmokeTests: XCTestCase {

    func testTypingShiftBackspaceAndProbeBadge() throws {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Type here to test the keyboard"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()

        // Cycle keyboards until ours is up (stock -> emoji -> SmartSpace).
        // Our keys are UIButtons ("space" exists as a button only on ours);
        // the stock QWERTY exposes "emoji", the emoji keyboard "Next keyboard".
        var hops = 0
        while !app.buttons["space"].waitForExistence(timeout: 3) {
            hops += 1
            XCTAssertLessThan(hops, 5, "SmartSpace keyboard never appeared")
            if app.buttons["Next keyboard"].exists {
                app.buttons["Next keyboard"].tap()
            } else if app.keys["Next keyboard"].exists {
                app.keys["Next keyboard"].tap()
            } else if app.buttons["emoji"].exists {
                app.buttons["emoji"].tap()
            } else {
                XCTFail("no keyboard switcher key found")
                break
            }
        }

        // Empty field -> auto-shift armed -> keys render uppercase.
        XCTAssertTrue(app.buttons["H"].waitForExistence(timeout: 3), "auto-shift did not arm")
        app.buttons["H"].tap()          // consumes the one-shot
        app.buttons["i"].tap()
        app.buttons["shift"].tap()      // manual one-shot
        app.buttons["J"].tap()
        app.buttons["space"].tap()
        app.buttons["m"].tap()
        app.buttons["⌫"].tap()

        // Double-tap shift = caps lock; letters stay uppercase across taps.
        app.buttons["shift"].doubleTap()
        app.buttons["O"].tap()
        app.buttons["K"].tap()
        app.buttons["shift"].tap()      // release caps lock

        // 123 layer carries punctuation; ABC returns.
        app.buttons["123"].tap()
        app.buttons["!"].tap()
        app.buttons["ABC"].tap()

        XCTAssertEqual(field.value as? String, "HiJ OK!")

        // App-group probe verdict (3.1): recorded from the badge either way.
        let ok = app.staticTexts["AG:OK"].exists
        let blocked = app.staticTexts["AG:BLOCKED"].exists
        XCTAssertTrue(ok || blocked, "probe badge missing")
        print("APP-GROUP-PROBE-VERDICT: \(ok ? "AG:OK" : "AG:BLOCKED")")
    }
}
