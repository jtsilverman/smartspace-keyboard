import XCTest

/// One-time setup helper: enables the SmartSpace keyboard by driving the
/// Settings app, the only supported path on simulator/device. Runs before
/// KeyboardSmokeTests alphabetically; idempotent (skips if already enabled).
final class EnableKeyboardTests: XCTestCase {

    func testEnableSmartSpaceKeyboardInSettings() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()

        let general = settings.cells.staticTexts["General"]
        XCTAssertTrue(general.waitForExistence(timeout: 10))
        general.tap()

        let keyboard = settings.cells.staticTexts["Keyboard"]
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        keyboard.tap()

        let keyboards = settings.cells.element(matching: NSPredicate(format: "label BEGINSWITH 'Keyboards'"))
        XCTAssertTrue(keyboards.waitForExistence(timeout: 5))
        keyboards.tap()

        if settings.cells.staticTexts["SmartSpace"].waitForExistence(timeout: 2) {
            return  // already enabled
        }

        let add = settings.descendants(matching: .any).element(
            matching: NSPredicate(format: "label BEGINSWITH 'Add New Keyboard'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let smartspace = settings.cells.staticTexts["SmartSpace"]
        XCTAssertTrue(smartspace.waitForExistence(timeout: 5), "SmartSpace missing from third-party keyboard list")
        smartspace.tap()

        XCTAssertTrue(settings.cells.staticTexts["SmartSpace"].waitForExistence(timeout: 5))
    }
}
