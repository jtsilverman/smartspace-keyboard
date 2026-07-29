import XCTest

/// Live verification of the 2.2 wiring (spec smart-symbols-wire AC 3-4):
/// contraction fix with undo protection, curly quotes, em dash.
final class SmartTypingTests: XCTestCase {

    func testContractionFixAppliesAndUndoProtects() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        // Auto-shift capitalizes the D; Dont -> Don't on commit.
        typeFirstLetter(app, field, "D", expecting: "D")
        for key in ["o", "n", "t"] { tapKey(app, key) }
        app.buttons["space"].tap()
        assertFieldValue(field, "Don\u{2019}t ",
                         "committed contraction should gain apostrophe")

        // Slot 0 = the typed original; tapping reverts and protects.
        let original = app.buttons["suggestion-0"]
        XCTAssertTrue(original.waitForExistence(timeout: 3), "bar missing")
        XCTAssertEqual(original.label, "Dont")
        original.tap()
        assertFieldValue(field, "Dont ", "undo should restore the typed word")

        for key in ["d", "o", "n", "t"] { tapKey(app, key) }
        app.buttons["space"].tap()
        assertFieldValue(field, "Dont dont ",
                         "an undone contraction must never be re-fixed")
    }

    func testCurlyQuotesAndEmDash() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        typeFirstLetter(app, field, "A", expecting: "A")
        app.buttons["123"].tap()
        XCTAssertTrue(app.buttons["\""].waitForExistence(timeout: 3))
        app.buttons["\""].tap()          // after "A": closing quote
        app.buttons["-"].tap()
        app.buttons["-"].tap()           // collapses to em dash
        app.buttons["\""].tap()          // after em dash: closing side? opener set decides
        assertFieldValue(field, "A\u{201D}\u{2014}\u{201D}",
                         "quote after letter closes; -- collapses to em dash")

        // Space then quote opens.
        app.buttons["space"].tap()
        app.buttons["\""].tap()
        assertFieldValue(field, "A\u{201D}\u{2014}\u{201D} \u{201C}",
                         "quote after a space should be an opening curly")
    }
}
