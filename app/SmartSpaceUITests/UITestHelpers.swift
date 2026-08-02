import XCTest

/// Shared plumbing for driving the real SmartSpace keyboard in the simulator.
extension XCTestCase {

    /// Launches into the practice field and cycles keyboards until SmartSpace
    /// (the only keyboard exposing a "space" UIButton) is up. Tolerates
    /// keyboard-appear animation: every probe waits instead of checking
    /// instantaneously. Bringup is the flakiest step of every suite (observed
    /// 2026-08-02: ~50% first-run failures after a state-reset reboot, both
    /// "never appeared" and kAXErrorCannotComplete on hop taps), so the whole
    /// flow is an atomic terminate+relaunch retry unit and hop taps go
    /// through coordinates, skipping the AX scroll-to-visible that errored.
    func focusSmartSpaceKeyboard(_ app: XCUIApplication) -> XCUIElement {
        for attempt in 0..<3 {
            if attempt > 0 {
                app.terminate()
                app.launch()
            }
            let field = app.textFields["Type here to test the keyboard"]
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            field.tap()

            // Bounded hops, not a bare while: a keyboard with no escape
            // element (e.g. a panel state) spun an unbounded loop for 40
            // minutes in the 2026-07-29 overnight run.
            for _ in 0..<8 {
                if app.buttons["space"].waitForExistence(timeout: 3) {
                    // Settle: a tap dispatched while the keyboard is still
                    // animating in can be swallowed (observed: first test's
                    // first letter tap lost, one-shot shift never consumed).
                    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                    return field
                }
                if app.buttons["Next keyboard"].exists {
                    tapCenter(app.buttons["Next keyboard"])
                } else if app.keys["Next keyboard"].exists {
                    tapCenter(app.keys["Next keyboard"])
                } else if app.buttons["emoji"].exists {
                    tapCenter(app.buttons["emoji"])
                }
                // else: a keyboard is still animating in; the loop's
                // waitForExistence provides the retry delay either way.
            }
        }
        XCTFail("SmartSpace keyboard never appeared after 3 launch attempts")
        return app.textFields["Type here to test the keyboard"]
    }

    /// Coordinate tap: same target as .tap() for an on-screen element, but
    /// never runs the AX scroll-to-visible action that can throw
    /// kAXErrorCannotComplete mid-keyboard-transition.
    private func tapCenter(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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
