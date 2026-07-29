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
