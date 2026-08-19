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

        // Eval v4 invariant: -- collapses only after a letter/digit
        // (so--anyway); after a quote it stays a literal hyphen run.
        typeFirstLetter(app, field, "A", expecting: "A")
        tapKey(app, "123")
        XCTAssertTrue(keyButton(app, "\"").waitForExistence(timeout: 3))
        tapKey(app, "\"")                // after "A": closing quote
        tapKey(app, "-")
        tapKey(app, "-")                 // after a quote: NO collapse
        assertFieldValue(field, "A\u{201D}--",
                         "quote after letter closes; -- after a quote stays literal")

        // Space then quote opens; -- after a letter collapses to an em dash.
        // A space on the 123 plane flips back to letters (KeyboardLayer
        // .didTypeSpace, stock behavior), so the quote needs 123 again.
        tapKey(app, "space")
        tapKey(app, "123")
        tapKey(app, "\"")
        tapKey(app, "ABC")
        tapKey(app, "b")
        tapKey(app, "123")
        tapKey(app, "-")
        tapKey(app, "-")
        assertFieldValue(field, "A\u{201D}-- \u{201C}b\u{2014}",
                         "quote after a space opens; -- after a letter collapses")
    }
}
