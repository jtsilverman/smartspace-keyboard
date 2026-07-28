import XCTest

/// Shared plumbing for driving the real SmartSpace keyboard in the simulator.
extension XCTestCase {

    /// Launches into the practice field and cycles keyboards until SmartSpace
    /// (the only keyboard exposing a "space" UIButton) is up. Tolerates
    /// keyboard-appear animation: every probe waits instead of checking
    /// instantaneously.
    func focusSmartSpaceKeyboard(_ app: XCUIApplication) -> XCUIElement {
        let field = app.textFields["Type here to test the keyboard"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()

        var hops = 0
        while !app.buttons["space"].waitForExistence(timeout: 3) {
            hops += 1
            XCTAssertLessThan(hops, 8, "SmartSpace keyboard never appeared")
            if app.buttons["Next keyboard"].exists {
                app.buttons["Next keyboard"].tap()
            } else if app.keys["Next keyboard"].exists {
                app.keys["Next keyboard"].tap()
            } else if app.buttons["emoji"].exists {
                app.buttons["emoji"].tap()
            }
            // else: a keyboard is still animating in; the loop's
            // waitForExistence provides the retry delay either way.
        }
        return field
    }

    /// Text edits from the extension land asynchronously; poll instead of
    /// reading the field once.
    func assertFieldValue(_ field: XCUIElement, _ expected: String,
                          _ message: String = "", timeout: TimeInterval = 5,
                          file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if field.value as? String == expected { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertEqual(field.value as? String, expected, message,
                       file: file, line: line)
    }
}
