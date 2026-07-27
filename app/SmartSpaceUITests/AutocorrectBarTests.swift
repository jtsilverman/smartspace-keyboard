import XCTest

/// Live verification of WORKPLAN 3.4 (spec AC 1, 2, 6): autocorrect fires on
/// word commit, the suggestion bar's original-word slot undoes and protects,
/// and an alternative slot swaps the corrected word.
final class AutocorrectBarTests: XCTestCase {

    func testCorrectionAppliesUndoTapRevertsAndProtects() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        // Auto-shift arms on the empty field: "Teh" -> commit -> "The ".
        app.buttons["T"].tap()
        app.buttons["e"].tap()
        app.buttons["h"].tap()
        app.buttons["space"].tap()
        assertFieldValue(field, "The ",
                         "space should commit Teh and autocorrect to The")

        // Slot 0 holds the original; tapping it reverts the text.
        let original = app.buttons["suggestion-0"]
        XCTAssertTrue(original.waitForExistence(timeout: 3), "suggestion bar missing")
        XCTAssertEqual(original.label, "Teh")
        original.tap()
        assertFieldValue(field, "Teh ", "undo tap should restore the original word")

        // Protected for the session: the same word commits uncorrected.
        app.buttons["t"].tap()
        app.buttons["e"].tap()
        app.buttons["h"].tap()
        app.buttons["space"].tap()
        assertFieldValue(field, "Teh teh ", "an undone word must never be re-corrected")
    }

    func testAlternativeTapSwapsCorrectedWord() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        app.buttons["T"].tap()
        app.buttons["e"].tap()
        app.buttons["h"].tap()
        app.buttons["space"].tap()
        assertFieldValue(field, "The ")

        // Alternatives come from Apple's checker; assert self-consistently
        // against whatever the slot shows rather than pinning its ranking.
        let alt = app.buttons["suggestion-1"]
        try XCTSkipUnless(alt.waitForExistence(timeout: 3),
                          "checker returned no alternatives for Teh on this OS")
        let altWord = alt.label
        alt.tap()
        assertFieldValue(field, "\(altWord) ",
                         "alternative tap should swap the corrected word")
    }
}
