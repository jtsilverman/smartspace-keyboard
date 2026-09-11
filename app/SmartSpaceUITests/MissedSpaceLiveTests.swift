import XCTest

/// Units 3 and 4a of specs/autocorrect-parity.md, driven on the real keyboard
/// (vision milestone 5, "missed spaces come back as words"). The engine tests
/// prove the split; this proves KeyboardViewController applies a candidate
/// that contains a space through textDocumentProxy without doubling or
/// dropping the space.
final class MissedSpaceLiveTests: XCTestCase {

    func testRunTogetherTokensComeBackAsTwoWords() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        clear(app, field)
        typeWord(app, field, "im")
        let afterIm = commitSpace(app, field, label: "im")
        typeWord(app, field, "onmy")
        let afterOnmy = commitSpace(app, field, label: "im onmy")
        XCTAssertTrue(
            matches(afterOnmy, anyOf: ["im on my", "i'm on my"]),
            "after `im onmy ` expected `I’m on my ` (or Im / I'm), field holds "
                + "\(quote(afterOnmy)); after `im ` it held \(quote(afterIm))")

        clear(app, field)
        typeWord(app, field, "call")
        let afterCall = commitSpace(app, field, label: "call")
        typeWord(app, field, "melater")
        let afterMelater = commitSpace(app, field, label: "call melater")
        XCTAssertTrue(
            matches(afterMelater, anyOf: ["call me later"]),
            "after `call melater ` expected `call me later `, field holds "
                + "\(quote(afterMelater)); after `call ` it held \(quote(afterCall))")
    }

    /// Taps the space key, waits for the field to settle, and records what it
    /// holds. Polls until the field stops changing: the split lands as a
    /// deleteBackward burst plus an insertText, and reading between the two
    /// would show a half-applied state.
    private func commitSpace(_ app: XCUIApplication, _ field: XCUIElement,
                             label: String) -> String {
        keyButton(app, "space").tap()
        var last = fieldText(field)
        var stable = 0
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, stable < 4 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            let now = fieldText(field)
            stable = now == last ? stable + 1 : 0
            last = now
        }
        let line = "FIELD-AFTER-SPACE [\(label) ] -> \(quote(last))"
        print(line)
        NSLog("%@", line)
        return last
    }

    /// Types each letter by tapping its key. Key titles flip case with the
    /// shift state (auto-shift on an empty field), so each letter resolves to
    /// whichever case is on screen. The first tap into an empty field is
    /// retried if it is swallowed during keyboard settle (see typeFirstLetter).
    private func typeWord(_ app: XCUIApplication, _ field: XCUIElement, _ word: String) {
        for letter in word {
            let before = fieldText(field)
            for attempt in 0..<3 {
                tapLetter(app, letter)
                let deadline = Date().addingTimeInterval(1.5)
                while Date() < deadline {
                    if fieldText(field).count > before.count { break }
                    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
                }
                if fieldText(field).count > before.count { break }
                XCTAssertTrue(attempt < 2, "letter \(letter) never landed; field holds \(quote(fieldText(field)))")
            }
        }
    }

    private func tapLetter(_ app: XCUIApplication, _ letter: Character) {
        let lower = keyButton(app, String(letter))
        let key = lower.exists ? lower : keyButton(app, String(letter).uppercased())
        XCTAssertTrue(key.waitForExistence(timeout: 3), "key \(letter) never appeared")
        key.tap()
    }

    /// Case-insensitive, apostrophe-style-insensitive, trailing-space-tolerant.
    private func matches(_ observed: String, anyOf accepted: [String]) -> Bool {
        let norm = observed.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .trimmingCharacters(in: .whitespaces)
        return accepted.contains(norm)
    }

    private func quote(_ s: String) -> String { "`\(s)`" }

    private func clear(_ app: XCUIApplication, _ field: XCUIElement) {
        let deadline = Date().addingTimeInterval(30)
        while fieldText(field) != "", Date() < deadline {
            app.buttons["⌫"].press(forDuration: 2.0)
        }
        XCTAssertEqual(fieldText(field), "", "field never cleared")
    }
}
