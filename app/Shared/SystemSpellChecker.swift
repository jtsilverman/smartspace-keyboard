import UIKit
import TypingEngine

/// The Phase-3.4 seam made real: UITextChecker behind the SpellChecking
/// protocol. Stateless; a fresh UITextChecker per call keeps it Sendable.
struct SystemSpellChecker: SpellChecking {
    func suggestions(for word: String) -> [String] {
        let checker = UITextChecker()
        let nsWord = word as NSString
        let range = NSRange(location: 0, length: nsWord.length)
        let miss = checker.rangeOfMisspelledWord(
            in: word, range: range, startingAt: 0, wrap: false, language: "en_US")
        guard miss.location != NSNotFound else { return [] }
        return checker.guesses(forWordRange: miss, in: word, language: "en_US") ?? []
    }
}
