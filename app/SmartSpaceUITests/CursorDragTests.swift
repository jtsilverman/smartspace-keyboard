import XCTest

/// Live verification of WORKPLAN 3.5 AC 2/3: long-press + slide on the
/// spacebar moves the cursor (and never inserts a space); a plain tap
/// still types one.
final class CursorDragTests: XCTestCase {

    func testSpacebarDragMovesCursorWithoutInsertingSpace() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        app.buttons["A"].tap()      // auto-shift arms on the empty field
        app.buttons["b"].tap()
        assertFieldValue(field, "Ab")

        // One full cursor step left (1.5 * stepWidth = deterministically
        // between one and two steps of 9pt).
        let space = app.buttons["space"]
        let start = space.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: -13.5, dy: 0))
        start.press(forDuration: 0.8, thenDragTo: end)

        app.buttons["x"].tap()
        assertFieldValue(field, "Axb",
                         "drag should move the cursor one step left, no space inserted")

        // Plain tap still types a space.
        app.buttons["space"].tap()
        assertFieldValue(field, "Ax b")
    }
}
