import XCTest

/// Measurement harness for stock-parity AC 1, not a regression test: brings
/// up the STOCK English keyboard in the practice field and prints every
/// key's frame, so the layout constants can copy real stock geometry for
/// this device class. Run on demand; asserts only that stock came up.
final class StockMetricsDumpTests: XCTestCase {

    func testDumpStockKeyboardMetrics() throws {
        let app = XCUIApplication()
        app.launch()
        let field = app.textFields["Type here to test the keyboard"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()

        // Hop until the stock keyboard (exposes XCUIElement keys) is up.
        var hops = 0
        while !app.keys["q"].waitForExistence(timeout: 3) && !app.keys["Q"].waitForExistence(timeout: 1) {
            hops += 1
            guard hops < 8 else {
                XCTFail("stock keyboard never appeared")
                return
            }
            if app.buttons["Next keyboard"].exists {
                app.buttons["Next keyboard"].tap()
            } else if app.keys["Next keyboard"].exists {
                app.keys["Next keyboard"].tap()
            } else if app.buttons["emoji"].exists {
                app.buttons["emoji"].tap()
            }
        }

        print("STOCK-METRICS screen=\(app.frame)")
        for key in app.keys.allElementsBoundByIndex {
            print("STOCK-METRICS key '\(key.identifier.isEmpty ? key.label : key.identifier)' frame=\(key.frame)")
        }
        for id in ["shift", "delete", "more", "space", "Return", "return", "Next keyboard", "emoji"] {
            let b = app.buttons[id]
            if b.exists { print("STOCK-METRICS button '\(id)' frame=\(b.frame)") }
        }
        let other = app.otherElements["Keyboard"]
        if other.exists { print("STOCK-METRICS keyboard frame=\(other.frame)") }

        // 123 plane: the punctuation row's geometry is measured, not guessed.
        if app.keys["more"].exists {
            app.keys["more"].tap()
            _ = app.keys["1"].waitForExistence(timeout: 3)
            for key in app.keys.allElementsBoundByIndex {
                print("STOCK-METRICS-123 key '\(key.identifier.isEmpty ? key.label : key.identifier)' frame=\(key.frame)")
            }
        }
    }
}
