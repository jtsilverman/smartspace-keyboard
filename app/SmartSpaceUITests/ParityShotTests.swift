import XCTest

/// Measurement harness for stock-parity AC 1, not a regression test: parks
/// the STOCK keyboard and then the SmartSpace keyboard in the same practice
/// field, attaching a full-screen shot of each and printing the key frames a
/// host-side pixel diff crops by. Run on demand, one device at a time.
final class ParityShotTests: XCTestCase {

    func testCaptureStockThenSmartSpace() throws {
        let app = XCUIApplication()
        app.launch()
        let field = app.textFields["Type here to test the keyboard"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()

        try hopToStock(app)
        disarmShift(app, uppercaseProbe: { app.keys["Q"].exists })
        print("PARITY screen=\(app.frame)")
        typeProbeLetter(app, key: app.keys["h"].exists ? app.keys["h"] : app.keys["H"])
        dumpFrames(app, side: "stock", keyQuery: app.keys, buttonQuery: app.buttons)
        print("PARITY stock q=\(app.keys["q"].exists ? app.keys["q"].frame : app.keys["Q"].frame)")
        for id in ["space", "return", "Return"] where app.keys[id].exists {
            print("PARITY stock \(id)=\(app.keys[id].frame)")
        }
        attach(app, name: "stock")

        try hopToSmartSpace(app)
        disarmShift(app, uppercaseProbe: { app.buttons["Q"].exists })
        typeProbeLetter(app, key: app.buttons["h"].exists ? app.buttons["h"] : app.buttons["H"])
        dumpFrames(app, side: "smartspace", keyQuery: app.buttons, buttonQuery: app.buttons)
        let smartQ = app.buttons["q"].exists ? app.buttons["q"] : app.buttons["Q"]
        print("PARITY smartspace q=\(smartQ.frame)")
        print("PARITY smartspace space=\(app.buttons["space"].frame)")
        attach(app, name: "smartspace")
    }

    /// The stock keyboard is the only one exposing XCUIElement keys.
    private func hopToStock(_ app: XCUIApplication) throws {
        for _ in 0..<10 {
            if app.keys["q"].waitForExistence(timeout: 2)
                || app.keys["Q"].waitForExistence(timeout: 1) { return }
            hop(app)
        }
        throw XCTSkip("stock keyboard never appeared")
    }

    /// SmartSpace is the only keyboard exposing a "space" UIButton.
    private func hopToSmartSpace(_ app: XCUIApplication) throws {
        for _ in 0..<10 {
            if app.buttons["space"].waitForExistence(timeout: 2) { return }
            hop(app)
        }
        throw XCTSkip("SmartSpace keyboard never appeared")
    }

    /// Auto-shift arms on an empty field, so one keyboard can render
    /// uppercase caps while the other renders lowercase and every glyph
    /// counts as a layout difference. Tap shift until both read lowercase.
    private func disarmShift(_ app: XCUIApplication, uppercaseProbe: () -> Bool) {
        for _ in 0..<3 where uppercaseProbe() {
            let shift = app.buttons["shift"].exists ? app.buttons["shift"] : app.keys["shift"]
            guard shift.exists else { return }
            shift.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        }
    }

    /// The candidate bar only renders once a word is under way, so both
    /// keyboards type one letter before the shot.
    private func typeProbeLetter(_ app: XCUIApplication, key: XCUIElement) {
        guard key.exists else { return }
        key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
    }

    /// The whole container plus every landmark a layout oracle needs: the
    /// bar above the keys, the key rows, and the bottom row holding the
    /// globe and the dictation control.
    private func dumpFrames(_ app: XCUIApplication, side: String,
                            keyQuery: XCUIElementQuery, buttonQuery: XCUIElementQuery) {
        let container = app.keyboards.element
        if container.exists { print("PARITY \(side) container=\(container.frame)") }
        for id in ["q", "a", "z", "space", "shift", "delete", "more", "123", "ABC",
                   "emoji", "emoji-key", "return", "Return", "return-key",
                   "Next keyboard", "Dictate", "dictate", "globe"] {
            if keyQuery[id].exists { print("PARITY \(side) key.\(id)=\(keyQuery[id].frame)") }
            else if buttonQuery[id].exists { print("PARITY \(side) btn.\(id)=\(buttonQuery[id].frame)") }
        }
        for id in ["completion-typed", "prediction-0", "prediction-1", "prediction-2",
                   "suggestion-0", "suggestion-1", "suggestion-2"] where buttonQuery[id].exists {
            print("PARITY \(side) bar.\(id)=\(buttonQuery[id].frame)")
        }
    }

    private func hop(_ app: XCUIApplication) {
        for candidate in [app.buttons["Next keyboard"], app.keys["Next keyboard"],
                          app.buttons["emoji"]] where candidate.exists {
            candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return
        }
    }

    private func attach(_ app: XCUIApplication, name: String) {
        // Settle: a shot taken mid keyboard-transition catches the animation.
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
