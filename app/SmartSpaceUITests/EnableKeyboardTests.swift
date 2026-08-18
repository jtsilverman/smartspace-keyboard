import XCTest

/// One-time setup helper: enables the SmartSpace keyboard by driving the
/// Settings app, the only supported path on simulator/device. Runs before
/// KeyboardSmokeTests alphabetically; idempotent (skips if already enabled).
/// Whole-navigation retry: Settings can restore into a stale sub-pane or
/// drop a tap under load, so each attempt starts from a fresh launch.
final class EnableKeyboardTests: XCTestCase {

    func testEnableSmartSpaceKeyboardInSettings() throws {
        // iOS lists a keyboard extension under "Add New Keyboard" only after
        // its container app runs once. On a freshly erased simulator the
        // SmartSpace row stayed missing through 8 Settings attempts across
        // 164s, then appeared on the first attempt after one app launch
        // (2026-08-17, Mac mini).
        let app = XCUIApplication()
        app.launch()
        app.terminate()

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        for attempt in 1...2 {
            settings.terminate()
            settings.launch()
            if enableViaSettings(settings) { return }
            XCTAssertLessThan(attempt, 2, "Settings navigation failed twice")
        }
    }

    private func enableViaSettings(_ settings: XCUIApplication) -> Bool {
        let general = settings.cells.staticTexts["General"]
        guard general.waitForExistence(timeout: 10) else {
            print("ENABLE-KEYBOARD failed at: root pane (General)")
            return false
        }
        general.tap()

        let keyboard = settings.cells.staticTexts["Keyboard"]
        guard keyboard.waitForExistence(timeout: 5) else {
            print("ENABLE-KEYBOARD failed at: General > Keyboard")
            return false
        }
        keyboard.tap()

        let keyboards = settings.cells.element(
            matching: NSPredicate(format: "label BEGINSWITH 'Keyboards'"))
        guard keyboards.waitForExistence(timeout: 5) else {
            print("ENABLE-KEYBOARD failed at: Keyboard > Keyboards")
            return false
        }
        keyboards.tap()

        if settings.cells.staticTexts["SmartSpace"].waitForExistence(timeout: 2) {
            return true  // already enabled
        }

        let add = settings.descendants(matching: .any).element(
            matching: NSPredicate(format: "label BEGINSWITH 'Add New Keyboard'")).firstMatch
        guard add.waitForExistence(timeout: 5) else {
            print("ENABLE-KEYBOARD failed at: Add New Keyboard row")
            return false
        }
        add.tap()

        let smartspace = settings.cells.staticTexts["SmartSpace"]
        guard smartspace.waitForExistence(timeout: 5) else {
            print("ENABLE-KEYBOARD failed at: SmartSpace row in the add list")
            return false
        }
        smartspace.tap()

        return settings.cells.staticTexts["SmartSpace"].waitForExistence(timeout: 5)
    }
}
