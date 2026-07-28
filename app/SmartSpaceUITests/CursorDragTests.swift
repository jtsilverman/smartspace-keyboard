import XCTest
import TypingEngine

/// Live verification of WORKPLAN 3.5 AC 2/3: long-press + slide on the
/// spacebar moves the cursor (and never inserts a space); a plain tap
/// still types one.
final class CursorDragTests: XCTestCase {

    func testSpacebarDragMovesCursorWithoutInsertingSpace() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        typeFirstLetter(app, field, "A", expecting: "A")  // auto-shift armed
        tapKey(app, "b")
        assertFieldValue(field, "Ab")

        // One full cursor step left (1.5 * stepWidth = deterministically
        // between one and two steps).
        let space = app.buttons["space"]
        let start = space.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(
            CGVector(dx: -1.5 * SpacebarCursorDrag.stepWidth, dy: 0))
        start.press(forDuration: 0.8, thenDragTo: end)

        // A drag never inserts a space; plain-tap space coverage lives in
        // the smoke test (kept out of here: a trailing space commit would
        // couple this test to live UITextChecker behavior on "Ax").
        tapKey(app, "x")
        assertFieldValue(field, "Axb",
                         "drag should move the cursor one step left, no space inserted")
    }
}
