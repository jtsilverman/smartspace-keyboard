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

    func completions(for prefix: String) -> [String] {
        let native = rawCompletions(for: prefix)
        // The dictionary only completes proper nouns (Wednesday, December)
        // from a capitalized prefix; a lowercase prefix merges them in so
        // "wednes" still reaches Wednesday.
        guard let first = prefix.first, first.isLowercase else { return native }
        let capitalized = rawCompletions(for: first.uppercased() + prefix.dropFirst())
            .filter { $0.first?.isUppercase == true && !native.contains($0) }
        guard let top = native.first else { return capitalized }
        // Slot the proper nouns right behind the native top pick so a
        // 3-slot bar can still reach them (mondo, Monday, ...).
        return [top] + capitalized + native.dropFirst()
    }

    private func rawCompletions(for prefix: String) -> [String] {
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: (prefix as NSString).length)
        return checker.completions(
            forPartialWordRange: range, in: prefix, language: "en_US") ?? []
    }
}
