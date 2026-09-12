import Testing
import Foundation
@testable import TypingEngine

/// Every one-key slip of the commonest words (eval/slips/slips.tsv), typed
/// through the engine alone, the way the typo bench types its pairs. Prints
/// corrected / left alone / miscorrected per kind. Report-style: the number
/// is coverage, and the rows where stock disagrees are the work list
/// (specs/autocorrect-loop.md, unit 3).
@Suite struct SlipBenchTests {
    struct Slip { let id: String; let kind: String; let intended: String; let typed: String }

    static func rows() throws -> [Slip] {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("eval/slips/slips.tsv")
        return try String(contentsOf: path, encoding: .utf8)
            .split(separator: "\n").dropFirst().map { line in
                let c = line.split(separator: "\t", omittingEmptySubsequences: false)
                return Slip(id: String(c[0]), kind: String(c[1]), intended: String(c[2]), typed: String(c[3]))
            }
    }

    /// Types the row word by word through the bar controller, so a split
    /// ("t he") can be joined back the way the keyboard does it.
    private static let checker = DictionarySpellChecker()

    private func run(_ typed: String) -> String {
        var controller = AutocorrectController(checker: Self.checker)
        var field = ""
        for word in typed.split(separator: " ", omittingEmptySubsequences: true) {
            field += (field.isEmpty ? "" : " ") + word
            if case .replace(let original, let corrected, _) = controller.wordCommitted(context: field) {
                field = String(field.dropLast(original.count)) + corrected
            }
        }
        return field.lowercased()
    }

    /// An unknown word costs the engine about 46ms in a debug build, so 158k
    /// rows is two hours and the judge needs the suite back in seconds. The
    /// suite scores every 256th row (about 620, every kind in proportion);
    /// SLIP_BENCH_ROWS=all scores them all for the nightly number.
    static func benchRows() throws -> [Slip] {
        let all = try rows()
        if ProcessInfo.processInfo.environment["SLIP_BENCH_ROWS"] == "all" { return all }
        return all.enumerated().filter { $0.offset % 256 == 0 }.map(\.element)
    }

    @Test func everySlipPerKind() throws {
        let rows = try Self.benchRows()
        var byKind: [String: (n: Int, ok: Int, left: Int, mis: Int)] = [:]
        for row in rows {
            var slot = byKind[row.kind] ?? (0, 0, 0, 0)
            slot.n += 1
            let out = run(row.typed)
            if out == row.intended { slot.ok += 1 }
            else if out == row.typed.lowercased() { slot.left += 1 }
            else { slot.mis += 1 }
            byKind[row.kind] = slot
        }
        for (kind, s) in byKind.sorted(by: { $0.key < $1.key }) {
            print("SLIP-BENCH \(kind): corrected \(s.ok)/\(s.n) (\(s.ok * 100 / max(s.n, 1))%)  left-alone \(s.left)  miscorrected \(s.mis)")
        }
        let total = byKind.values.reduce((0, 0, 0)) { ($0.0 + $1.n, $0.1 + $1.ok, $0.2 + $1.mis) }
        print("SLIP-BENCH total: corrected \(total.1)/\(total.0) (\(total.1 * 100 / max(total.0, 1))%)  miscorrected \(total.2)")
        #expect(rows.count > 500, "the slip corpus lost rows")
    }
}
