import XCTest

/// Keyboard-wide blind eval v4: end-to-end keystroke scenarios (eval/v4/
/// scenarios.tsv) driven against the real keyboard extension. Report-style:
/// every scenario runs, misses print, the suite fails only on harness errors.
final class ScenarioEvalTests: XCTestCase {

    private static let placeholder = "Type here to test the keyboard"
    private static let numberChars = Set("1234567890-/:;()$&@\".,?!'")
    private static let symbolOnlyChars = Set("[]{}#%^*+=_\\|~<>")

    func testScenarioEvalReport() throws {
        let app = XCUIApplication()
        app.launch()
        let field = focusSmartSpaceKeyboard(app)

        var pass = 0, fail = 0, skipped = 0
        for scenario in scenarioCorpus {
            if scenario.script.contains("{RET}") {
                // Practice field is a single-line TextField; return-key
                // scenarios need a multiline host surface (recorded, not run).
                print("SCENARIO-SKIP \(scenario.id) (\(scenario.title)): {RET} unsupported in practice field")
                skipped += 1
                continue
            }
            clearField(app, field)
            run(script: scenario.script, app: app)
            let got = fieldText(field)
            if matches(got: got, scenario: scenario) {
                pass += 1
            } else {
                fail += 1
                print("SCENARIO-MISS \(scenario.id) (\(scenario.title)) [\(scenario.tolerance)]")
                print("  want: \(scenario.expected.debugDescription)")
                print("  got:  \(got.debugDescription)")
            }
        }
        print("SCENARIO-BENCH pass \(pass)/\(pass + fail) (skipped \(skipped))")
        XCTAssertEqual(pass + fail + skipped, scenarioCorpus.count)
        XCTAssertGreaterThan(pass, 0)
    }

    private func matches(got raw: String, scenario: ScenarioCase) -> Bool {
        let got = raw.replacingOccurrences(of: Self.placeholder, with: "")
        var accepted = [scenario.expected]
        if let altRange = scenario.note.range(of: "ALT:") {
            accepted.append(
                scenario.note[altRange.upperBound...].trimmingCharacters(in: .whitespaces))
        }
        return accepted.contains { want in
            if scenario.tolerance == "exact" { return got == want }
            // punct-top2 rows may also end mid-cycle with a trailing space;
            // loose-ws ignores trailing whitespace outright.
            let trimmedGot = got.trimmingTrailingWhitespace()
            let trimmedWant = want.trimmingTrailingWhitespace()
            return trimmedGot == trimmedWant
        }
    }

    private func fieldText(_ field: XCUIElement) -> String {
        let value = field.value as? String ?? ""
        return value == Self.placeholder ? "" : value
    }

    /// Long-press backspace clears via the repeat timer; poll until the
    /// placeholder (empty field) comes back.
    private func clearField(_ app: XCUIApplication, _ field: XCUIElement) {
        let deadline = Date().addingTimeInterval(30)
        while fieldText(field) != "", Date() < deadline {
            app.buttons["⌫"].press(forDuration: 2.0)
        }
        XCTAssertEqual(fieldText(field), "", "field never cleared")
    }

    private func run(script: String, app: XCUIApplication) {
        var rest = Substring(script)
        while let ch = rest.first {
            if ch == "{" , let close = rest.firstIndex(of: "}") {
                let token = String(rest[rest.index(after: rest.startIndex)..<close])
                rest = rest[rest.index(after: close)...]
                switch token {
                case "SP": app.buttons["space"].tap()
                case "DSP": app.buttons["space"].doubleTap()
                case "BS": app.buttons["⌫"].tap()
                case "RET": app.buttons["return-key"].tap()
                default: XCTFail("unknown script token {\(token)}")
                }
                continue
            }
            rest = rest.dropFirst()
            typeChar(ch, app: app)
        }
    }

    private func typeChar(_ ch: Character, app: XCUIApplication) {
        if ch == " " { app.buttons["space"].tap(); return }
        let s = String(ch)
        if ch.isLetter {
            ensureLettersPlane(app)
            if app.buttons[s].waitForExistence(timeout: 2) {
                app.buttons[s].tap()
            } else if ch.isUppercase, app.buttons[s.lowercased()].exists {
                // Manual capital: arm one-shot shift, key titles flip.
                app.buttons["shift"].tap()
                tapKey(app, s)
            } else if ch.isLowercase, app.buttons[s.uppercased()].exists {
                // Auto-shift armed but the script wants lowercase: consume it.
                // (Stock behavior types the capital; scripts assume the user
                // accepts autocap, so tap the uppercase key.)
                tapKey(app, s.uppercased())
            } else {
                XCTFail("letter key \(s) not found on any case")
            }
            return
        }
        if Self.numberChars.contains(ch) {
            ensurePlane(app, key: "123", probe: "1")
            tapKey(app, s)
            return
        }
        if Self.symbolOnlyChars.contains(ch) {
            ensurePlane(app, key: "123", probe: "1")
            ensurePlane(app, key: "#+=", probe: "[")
            tapKey(app, s)
            return
        }
        XCTFail("no key mapping for character \(s.debugDescription)")
    }

    private func ensureLettersPlane(_ app: XCUIApplication) {
        if app.buttons["ABC"].exists { app.buttons["ABC"].tap() }
    }

    private func ensurePlane(_ app: XCUIApplication, key: String, probe: String) {
        if !app.buttons[probe].exists, app.buttons[key].waitForExistence(timeout: 2) {
            app.buttons[key].tap()
        }
    }
}

private extension String {
    func trimmingTrailingWhitespace() -> String {
        var s = Substring(self)
        while s.last?.isWhitespace == true { s = s.dropLast() }
        return String(s)
    }
}
