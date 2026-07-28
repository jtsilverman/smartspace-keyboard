import XCTest

/// Live smoke test for the 3.1 scaffold: drives the REAL keyboard extension in
/// the simulator and asserts what lands in the text field. Requires the
/// SmartSpace keyboard to be enabled on the target device (CI/dev: written into
/// com.apple.Preferences AppleKeyboards before the run).
final class KeyboardSmokeTests: XCTestCase {

    func testTypingShiftBackspaceAndProbeBadge() throws {
        let app = XCUIApplication()
        app.launch()

        let field = focusSmartSpaceKeyboard(app)

        // Empty field -> auto-shift armed -> keys render uppercase.
        XCTAssertTrue(app.buttons["H"].waitForExistence(timeout: 3), "auto-shift did not arm")
        typeFirstLetter(app, field, "H", expecting: "H")  // consumes the one-shot
        tapKey(app, "i")
        app.buttons["shift"].tap()      // manual one-shot
        tapKey(app, "J")
        app.buttons["space"].tap()
        tapKey(app, "m")
        app.buttons["⌫"].tap()

        // Double-tap shift = caps lock; letters stay uppercase across taps.
        app.buttons["shift"].doubleTap()
        tapKey(app, "O")
        tapKey(app, "K")
        app.buttons["shift"].tap()      // release caps lock

        // 123 layer carries punctuation; ABC returns.
        app.buttons["123"].tap()
        app.buttons["!"].tap()
        app.buttons["ABC"].tap()

        assertFieldValue(field, "HiJ OK!")

        // Hero feature: double-space inserts the engine's top mark, another
        // space cycles it in place, and typing ends the cycle.
        app.buttons["space"].tap()
        tapKey(app, "H")          // auto-shift armed after "! "
        tapKey(app, "o")
        tapKey(app, "w")
        app.buttons["space"].tap()
        tapKey(app, "a")
        tapKey(app, "r")
        tapKey(app, "e")
        app.buttons["space"].tap()
        tapKey(app, "u")
        app.buttons["space"].doubleTap()
        assertFieldValue(field, "HiJ OK! How are u? ",
                         "double-space should insert the question mark")
        app.buttons["space"].tap()
        assertFieldValue(field, "HiJ OK! How are u. ",
                         "space again should cycle ? -> .")
        tapKey(app, "K")          // typing ends the cycle; auto-shift caps it
        assertFieldValue(field, "HiJ OK! How are u. K")

        // App-group probe verdict (3.1): recorded from the badge either way.
        let ok = app.staticTexts["AG:OK"].exists
        let blocked = app.staticTexts["AG:BLOCKED"].exists
        XCTAssertTrue(ok || blocked, "probe badge missing")
        print("APP-GROUP-PROBE-VERDICT: \(ok ? "AG:OK" : "AG:BLOCKED")")
    }
}
