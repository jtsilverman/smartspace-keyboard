import XCTest
import TypingEngine

// SystemSpellChecker lives in app/Shared (single copy, used by the extension
// and these tests).
final class SystemSpellCheckerTests: XCTestCase {
    func testKnownTypoYieldsIntendedWord() {
        let suggestions = SystemSpellChecker().suggestions(for: "teh")
        XCTAssertTrue(suggestions.contains("the"), "got: \(suggestions)")
    }

    func testCorrectWordYieldsNoSuggestions() {
        XCTAssertEqual(SystemSpellChecker().suggestions(for: "hello"), [])
    }

    func testPartialWordYieldsDictionaryCompletions() {
        // The dictionary service can return [] on its first call after
        // process start (observed once, then probe runs all succeeded);
        // retry briefly before judging.
        var completions: [String] = []
        for _ in 0..<10 {
            completions = SystemSpellChecker().completions(for: "keyb")
            if !completions.isEmpty { break }
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue(completions.contains("keyboard"), "got: \(completions)")
    }
}
