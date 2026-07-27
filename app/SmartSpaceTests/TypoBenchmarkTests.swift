import XCTest
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

final class SystemSpellCheckerTests: XCTestCase {
    func testKnownTypoYieldsIntendedWord() {
        let suggestions = SystemSpellChecker().suggestions(for: "teh")
        XCTAssertTrue(suggestions.contains("the"), "got: \(suggestions)")
    }

    func testCorrectWordYieldsNoSuggestions() {
        XCTAssertEqual(SystemSpellChecker().suggestions(for: "hello"), [])
    }
}

/// Autocorrect benchmark (EVAL.md): 320 blind-generated typo->intended pairs
/// through the real CorrectionEngine + UITextChecker. Reports corrected /
/// left-alone / miscorrected per category; miscorrection is the expensive
/// failure. Baseline report -- gate set from evidence, not guessed.
final class TypoBenchmarkTests: XCTestCase {
    func testTypoCorpusBaselineReport() {
        let engine = CorrectionEngine(checker: SystemSpellChecker())
        var corrected = 0, leftAlone = 0, miscorrected = 0
        var byCategory: [String: (n: Int, ok: Int, mis: Int)] = [:]

        for pair in typoCorpus {
            var slot = byCategory[pair.category] ?? (0, 0, 0)
            slot.n += 1
            switch engine.decision(for: pair.typo) {
            case .correct(let to, _) where to.lowercased() == pair.intended.lowercased():
                corrected += 1; slot.ok += 1
            case .correct(let to, _):
                miscorrected += 1; slot.mis += 1
                print("TYPO-MISCORRECT [\(pair.category)] \(pair.typo) -> \(to) wanted \(pair.intended)")
            case .noChange:
                leftAlone += 1
                print("TYPO-MISSED [\(pair.category)] \(pair.typo) wanted \(pair.intended)")
            }
            byCategory[pair.category] = slot
        }

        let n = typoCorpus.count
        print("TYPO-BENCH corrected \(corrected)/\(n) (\(corrected * 100 / n)%)  left-alone \(leftAlone)  miscorrected \(miscorrected)")
        for (cat, s) in byCategory.sorted(by: { $0.key < $1.key }) {
            print("  \(cat): corrected \(s.ok)/\(s.n)  miscorrected \(s.mis)")
        }
        XCTAssertEqual(corrected + leftAlone + miscorrected, n)
        XCTAssertGreaterThan(corrected, 0)
    }
}
