import XCTest
@testable import TypingEngine

/// Vision milestone 5: "sloppy thumbs land on the word stock lands on".
/// Unit 1 of specs/autocorrect-parity.md makes our own dictionary the
/// candidate source, so a common typo must reach its intended word with no
/// UITextChecker in the path.
final class DictionarySpellCheckerTests: XCTestCase {
    func testCommonTypoReachesItsIntendedWord() {
        let suggestions = DictionarySpellChecker().suggestions(for: "teh")
        XCTAssertTrue(suggestions.contains("the"), "got: \(suggestions)")
    }
}
