import XCTest

/// Live verification of the completions bar (spec completions-bar AC 6-7):
/// mid-word completions fill the bar; a completion tap finishes the word;
/// the verbatim tap keeps the typed word and shields it from autocorrect.
final class CompletionBarTests: XCTestCase {

    func testCompletionTapFinishesTheWord() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        typeFirstLetter(app, field, "K", expecting: "K")
        for key in ["e", "y", "b"] { tapKey(app, key) }
        assertFieldValue(field, "Keyb")

        let typedSlot = app.buttons["completion-typed"]
        XCTAssertTrue(typedSlot.waitForExistence(timeout: 3), "verbatim slot missing")
        XCTAssertEqual(typedSlot.label, "\u{201C}Keyb\u{201D}")

        // Assert self-consistently against whatever Apple's dictionary
        // offers, like the alternative-swap test.
        let completion = app.buttons["completion-1"]
        try XCTSkipUnless(completion.waitForExistence(timeout: 3),
                          "no completions for Keyb on this OS")
        let word = completion.label
        completion.tap()
        assertFieldValue(field, "\(word) ",
                         "completion tap should finish the word and add a space")
    }

    func testVerbatimTapAcceptsAndShieldsFromAutocorrect() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        // "Teh" would autocorrect on commit; the verbatim tap must not.
        typeFirstLetter(app, field, "T", expecting: "T")
        for key in ["e", "h"] { tapKey(app, key) }
        let typedSlot = app.buttons["completion-typed"]
        XCTAssertTrue(typedSlot.waitForExistence(timeout: 3), "verbatim slot missing")
        typedSlot.tap()
        assertFieldValue(field, "Teh ", "verbatim tap keeps the word as typed")

        // Protection outlives the tap: a normal commit stays uncorrected.
        for key in ["t", "e", "h"] { tapKey(app, key) }
        app.buttons["space"].tap()
        assertFieldValue(field, "Teh teh ",
                         "a verbatim-accepted word must never be auto-corrected")
    }
}
