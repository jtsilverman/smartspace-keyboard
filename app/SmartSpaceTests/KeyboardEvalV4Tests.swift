import XCTest
import TypingEngine

/// Keyboard-wide blind eval v4 (specs/keyboard-eval.md): the checker-dependent
/// sets, scored through the real CorrectionEngine + UITextChecker like the v3
/// typo benchmark. Dev misses may be studied; test halves aggregate only.

/// Protection set: strings autocorrect must leave untouched. Any .correct
/// decision is a failure (the expensive kind -- mangling intended text).
final class ProtectionEvalTests: XCTestCase {
    private func score(_ rows: [ProtectCase], name: String, printMisses: Bool) {
        let engine = CorrectionEngine(checker: SystemSpellChecker())
        var ok = 0
        var missesBySub: [String: [String]] = [:]
        for r in rows {
            // decision(for:) takes the full field text and extracts the last
            // word itself; join context and typed the way the field would.
            var field = r.context
            if !field.isEmpty, field.last?.isWhitespace == false { field += " " }
            field += r.typed
            switch engine.decision(for: field) {
            case .noChange:
                ok += 1
            case .correct(let to, _):
                missesBySub[r.sub, default: []].append("\(r.id):\(r.typed)->\(to)")
            }
        }
        print("[\(name)] left-alone \(ok)/\(rows.count) (\(ok * 100 / max(rows.count, 1))%)")
        if printMisses {
            for (sub, ids) in missesBySub.sorted(by: { $0.value.count > $1.value.count }) {
                print("  touched \(sub): \(ids.count) \(ids.joined(separator: " "))")
            }
        }
        XCTAssertEqual(ok + missesBySub.values.map(\.count).reduce(0, +), rows.count)
    }

    func testProtectionDevReport() {
        score(protectCorpus.filter { $0.half == "dev" }, name: "PROTECT DEV", printMisses: true)
    }

    func testProtectionTestReport() {
        score(protectCorpus.filter { $0.half == "test" }, name: "PROTECT TEST", printMisses: false)
    }
}

/// v4 typo pairs (casual register, modern vocabulary) -- same scoring as the
/// frozen v3 typo benchmark, separate corpus.
final class TypoBenchmarkV4Tests: XCTestCase {
    func testTypoV4Report() {
        let engine = CorrectionEngine(checker: SystemSpellChecker())
        var corrected = 0, leftAlone = 0, miscorrected = 0
        var byCategory: [String: (n: Int, ok: Int, mis: Int)] = [:]
        // Engine contraction fixes use the curly apostrophe; intended
        // columns are straight-typed. Normalize both before comparing.
        func normalized(_ s: String) -> String {
            s.replacingOccurrences(of: "\u{2019}", with: "'").lowercased()
        }
        for pair in typoCorpusV4 {
            var slot = byCategory[pair.category] ?? (0, 0, 0)
            slot.n += 1
            switch engine.decision(for: pair.typo) {
            case .correct(let to, _) where normalized(to) == normalized(pair.intended):
                corrected += 1; slot.ok += 1
            case .correct(let to, _):
                miscorrected += 1; slot.mis += 1
                print("TYPO4-MISCORRECT [\(pair.category)] \(pair.typo) -> \(to) wanted \(pair.intended)")
            case .noChange:
                leftAlone += 1
                print("TYPO4-MISSED [\(pair.category)] \(pair.typo) wanted \(pair.intended)")
            }
            byCategory[pair.category] = slot
        }
        let n = typoCorpusV4.count
        print("TYPO4-BENCH corrected \(corrected)/\(n) (\(corrected * 100 / n)%)  left-alone \(leftAlone)  miscorrected \(miscorrected)")
        for (cat, s) in byCategory.sorted(by: { $0.key < $1.key }) {
            print("  \(cat): corrected \(s.ok)/\(s.n)  miscorrected \(s.mis)")
        }
        XCTAssertEqual(corrected + leftAlone + miscorrected, n)
    }
}

/// Completions: prefix -> any acceptable completion in the top 3 offered.
/// acceptable == ["NONE"] passes when nothing (or only the prefix) is offered.
final class CompletionEvalTests: XCTestCase {
    private func score(_ rows: [CompletionCase], name: String, printMisses: Bool) {
        let checker = SystemSpellChecker()
        var ok = 0
        var missesBySub: [String: [String]] = [:]
        for r in rows {
            // First dictionary call after process start can return [] once
            // (v3 benchmark observation); retry briefly.
            var offered: [String] = []
            for _ in 0..<3 {
                offered = Array(checker.completions(for: r.prefix).prefix(3))
                if !offered.isEmpty { break }
                Thread.sleep(forTimeInterval: 0.2)
            }
            let pass: Bool
            if r.acceptable == ["NONE"] {
                pass = offered.allSatisfy { $0.lowercased() == r.prefix.lowercased() }
            } else {
                pass = offered.contains { o in
                    r.acceptable.contains { $0.lowercased() == o.lowercased() }
                }
            }
            if pass {
                ok += 1
            } else {
                missesBySub[r.sub, default: []].append("\(r.id):\(r.prefix)->[\(offered.joined(separator: ","))]")
            }
        }
        print("[\(name)] \(ok)/\(rows.count) (\(ok * 100 / max(rows.count, 1))%)")
        if printMisses {
            for (sub, ids) in missesBySub.sorted(by: { $0.value.count > $1.value.count }) {
                print("  miss \(sub): \(ids.count) \(ids.joined(separator: " "))")
            }
        }
        XCTAssertGreaterThan(ok, 0)
    }

    func testCompletionsDevReport() {
        score(completionCorpus.filter { $0.half == "dev" }, name: "COMPLETIONS DEV", printMisses: true)
    }

    func testCompletionsTestReport() {
        score(completionCorpus.filter { $0.half == "test" }, name: "COMPLETIONS TEST", printMisses: false)
    }
}
