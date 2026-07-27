import XCTest

/// Live verification of WORKPLAN 3.6 (spec AC 4-7): panel toggle, grid
/// insert, recents, and search mode.
final class EmojiPanelTests: XCTestCase {

    func testPanelInsertRecentsAndReturnToLetters() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        // AC4: open panel (fresh install has no recents -> smileys grid).
        app.buttons["emoji-key"].tap()
        let grinning = app.buttons["emoji-item-😀"]
        XCTAssertTrue(grinning.waitForExistence(timeout: 3), "emoji grid missing")
        grinning.tap()
        assertFieldValue(field, "😀")

        // AC6: category tab switches the grid.
        app.buttons["emoji-cat-food"].tap()
        XCTAssertTrue(app.buttons["emoji-item-🍕"].waitForExistence(timeout: 3),
                      "food category grid missing")

        // AC5: recents tab shows the inserted emoji first (only recent, so
        // it is the first cell).
        app.buttons["emoji-cat-recents"].tap()
        XCTAssertTrue(app.buttons["emoji-item-😀"].waitForExistence(timeout: 3),
                      "recents missing the inserted emoji")

        // AC4: ABC restores letters and typing works. Auto-shift is still
        // armed (an emoji at message start does not consume the one-shot),
        // so the keys render uppercase.
        app.buttons["emoji-abc"].tap()
        XCTAssertTrue(app.buttons["space"].waitForExistence(timeout: 3))
        app.buttons["A"].tap()
        assertFieldValue(field, "😀A")
    }

    func testSearchModeFiltersAndInsertsWithoutTouchingDocument() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        app.buttons["A"].tap()      // auto-shift arms on the empty field
        assertFieldValue(field, "A")

        app.buttons["emoji-key"].tap()
        XCTAssertTrue(app.buttons["emoji-search"].waitForExistence(timeout: 3))
        app.buttons["emoji-search"].tap()

        // AC7: backspace on an empty query leaves the document alone.
        XCTAssertTrue(app.buttons["⌫"].waitForExistence(timeout: 3))
        app.buttons["⌫"].tap()
        assertFieldValue(field, "A", "empty-query backspace must not edit the document")

        // Typing filters emoji instead of inserting letters.
        for key in ["p", "i", "z", "z", "a"] { app.buttons[key].tap() }
        assertFieldValue(field, "A", "search letters must not reach the document")
        let pizza = app.buttons["emoji-item-🍕"]
        XCTAssertTrue(pizza.waitForExistence(timeout: 3), "search result missing")

        // Result tap inserts and exits search.
        pizza.tap()
        assertFieldValue(field, "A🍕")
        XCTAssertFalse(app.buttons["emoji-search-cancel"].exists,
                       "search strip should be gone after insert")
    }

    func testSearchCancelExitsWithoutInserting() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        app.buttons["Z"].tap()      // anchor text (empty field reads as placeholder)
        assertFieldValue(field, "Z")

        app.buttons["emoji-key"].tap()
        XCTAssertTrue(app.buttons["emoji-search"].waitForExistence(timeout: 3))
        app.buttons["emoji-search"].tap()
        XCTAssertTrue(app.buttons["emoji-search-cancel"].waitForExistence(timeout: 3))
        app.buttons["emoji-search-cancel"].tap()
        assertFieldValue(field, "Z", "cancel must not insert anything")
        XCTAssertTrue(app.buttons["space"].waitForExistence(timeout: 3),
                      "letters should be back after cancel")
    }
}
