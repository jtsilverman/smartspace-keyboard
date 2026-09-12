import Testing
@testable import TypingEngine

/// Autocorrect benchmark (EVAL.md): 320 blind-generated typo -> intended pairs
/// through the real CorrectionEngine. Reports corrected / left-alone /
/// miscorrected per category; miscorrection is the expensive failure.
/// Check 2 of specs/autocorrect-parity.md: the gate is where UITextChecker
/// left it, so our own dictionary may not buy coverage back with
/// miscorrections. Pure Swift since unit 1, so it runs under swift test.
@Suite struct TypoBenchmarkTests {
    @Test func typoCorpusBaselineReport() {
        let engine = CorrectionEngine(checker: DictionarySpellChecker())
        var corrected = 0, leftAlone = 0, miscorrected = 0
        var byCategory: [String: (n: Int, ok: Int, mis: Int)] = [:]

        for pair in typoCorpus {
            var slot = byCategory[pair.category] ?? (0, 0, 0)
            slot.n += 1
            switch engine.decision(for: pair.typo) {
            case .correct(let to, _) where to.lowercased() == pair.intended.lowercased():
                corrected += 1; slot.ok += 1
            case .correct(let to, _), .join(let to, _, _):
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
        #expect(corrected + leftAlone + miscorrected == n)
        #expect(corrected * 100 / n >= 90, "corrected \(corrected)/\(n)")
        #expect(miscorrected <= 23, "miscorrected \(miscorrected)")
    }
}
