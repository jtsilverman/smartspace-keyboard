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
        // Settle: a tap dispatched while the keyboard is still animating in
        // can be swallowed (observed: first test's first letter tap lost,
        // one-shot shift never consumed).
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        return field
    }

    /// Key titles flip case in place when shift state changes (T consumes
    /// the one-shot -> keys rerender lowercase); an immediate query can race
    /// that refresh. Wait for the key before tapping.
    func tapKey(_ app: XCUIApplication, _ title: String,
                file: StaticString = #filePath, line: UInt = #line) {
        let key = app.buttons[title]
        XCTAssertTrue(key.waitForExistence(timeout: 3),
                      "key \(title) never appeared", file: file, line: line)
        key.tap()
    }

    /// The first tap after keyboard bringup is occasionally swallowed under
    /// simulator load (observed: field never receives it, one-shot shift
    /// never consumed). Tap, verify the field, retap if it vanished.
    func typeFirstLetter(_ app: XCUIApplication, _ field: XCUIElement,
                         _ title: String, expecting: String,
                         file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<3 {
            tapKey(app, title, file: file, line: line)
            let deadline = Date().addingTimeInterval(1.5)
            while Date() < deadline {
                if (field.value as? String) == expecting { return }
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
        }
        XCTFail("first letter \(title) never landed as \(expecting)",
                file: file, line: line)
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
