import XCTest

/// Fast-typing mechanics (stock-parity AC 2, simulator half): burst-taps a
/// pangram through cached key coordinates with NO per-tap AX queries or
/// waits, then asserts the field holds every character. Catches dropped
/// hits from synchronous work on the tap path (the stock-parity regression
/// Jake felt on device). XCUITest cannot roll touches (next key down before
/// last key up), so rolled multitouch stays device-verified; this covers
/// maximum sequential tap rate.
final class FastTypingTests: XCTestCase {

    func testBurstTypingDropsNoCharacters() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        // Consume the auto-shift one-shot so every later key face is lowercase.
        XCTAssertTrue(app.buttons["T"].waitForExistence(timeout: 3), "auto-shift did not arm")
        typeFirstLetter(app, field, "T", expecting: "T")

        // Every word is correctly spelled: autocorrect must pass each one
        // through untouched, so any mismatch below is a dropped/wrong hit.
        let rest = "he quick brown fox jumps over the lazy dog"

        // Cache one coordinate per distinct key up front; the burst loop
        // then fires taps positionally at full XCTest speed.
        var coords: [Character: XCUICoordinate] = [:]
        for ch in Set(rest) {
            let title = ch == " " ? "space" : String(ch)
            let key = app.buttons[title]
            XCTAssertTrue(key.waitForExistence(timeout: 3), "key \(title) missing")
            coords[ch] = key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        }
        for ch in rest {
            coords[ch]!.tap()
        }

        assertFieldValue(field, "The quick brown fox jumps over the lazy dog",
                         "burst typing dropped or mangled characters", timeout: 10)
    }
}
