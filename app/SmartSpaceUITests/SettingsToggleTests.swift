import XCTest

/// Live verification of 4.2 extension consumption (spec host-app-settings
/// AC 3): the keyboard honors app-group settings on its next appearance.
/// The app seeds the settings itself via the -uitest-smart-features-off/on
/// launch arguments (the real SettingsWriter path); every test restores by
/// relaunching with -on in a teardown block. Direct plist seeding is
/// invisible through cfprefsd, and SwiftUI Form toggle taps do not register
/// on the iOS 26.5 simulator (toggle-tap coverage is spec AC 4, open).
final class SettingsToggleTests: XCTestCase {

    private func launchAllOff(_ app: XCUIApplication) {
        app.launchArguments = ["-uitest-smart-features-off"]
        app.launch()
        addTeardownBlock {
            let restore = XCUIApplication()
            restore.launchArguments = ["-uitest-smart-features-on"]
            restore.launch()
            restore.terminate()
        }
    }

    func testSmartDoubleSpaceOffYieldsPlainSpaces() throws {
        let app = XCUIApplication()
        launchAllOff(app)
        let field = focusSmartSpaceKeyboard(app)
        // Auto-capitalization is also off: keys render lowercase.
        typeFirstLetter(app, field, "h", expecting: "h")
        tapKey(app, "i")
        app.buttons["space"].tap()
        app.buttons["space"].tap()
        assertFieldValue(field, "hi  ",
                         "double-space with the setting off must insert two plain spaces")
    }

    func testAutocorrectOffLeavesTypoAndBarEmpty() throws {
        let app = XCUIApplication()
        launchAllOff(app)
        let field = focusSmartSpaceKeyboard(app)
        // Auto-capitalization is also off: keys render lowercase.
        typeFirstLetter(app, field, "t", expecting: "t")
        for key in ["e", "h"] { tapKey(app, key) }
        app.buttons["space"].tap()
        assertFieldValue(field, "teh ",
                         "autocorrect off must commit the word exactly as typed")
        XCTAssertFalse(app.buttons["suggestion-0"].exists,
                       "suggestion bar must stay empty with autocorrect off")
    }
}
