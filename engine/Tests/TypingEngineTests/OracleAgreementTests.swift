import Testing
import Foundation
@testable import TypingEngine

/// How often our engine produces what the real stock keyboard produced, over
/// the frozen 400-row corpus (`eval/oracle/stock-*.tsv`). Checks 3 and 4 of
/// specs/autocorrect-parity.md are percentages of exactly this.
///
/// Report-style: every row runs and the numbers print. The suite fails only if
/// the corpus is the wrong size, because the recording is a recording. Its
/// drift gate failed on 2026-08-20 with two rows in thirty moving, so a row we
/// disagree on is a lead, never a verdict.
@Suite struct OracleAgreementTests {

    /// Types a row the way the keyboard does: each space commits the word
    /// before it, and the correction rewrites what is already in the field.
    private func run(_ typed: String) -> String {
        let engine = CorrectionEngine(checker: DictionarySpellChecker())
        var field = ""
        for word in typed.split(separator: " ", omittingEmptySubsequences: true) {
            field += (field.isEmpty ? "" : " ") + word
            if case .correct(let to, _) = engine.decision(for: field) {
                field = String(field.dropLast(word.count)) + to
            }
        }
        return field
    }

    /// Case and apostrophe style are the autocap and smart-punctuation rules'
    /// business, which the recording carries and this comparison is not about.
    private func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .trimmingCharacters(in: .whitespaces)
    }

    @Test func agreementWithStockPerSlice() {
        var totals: [String: (agree: Int, n: Int)] = [:]
        var misses: [String: [String]] = [:]
        for row in oracleAnswers {
            var slot = totals[row.slice] ?? (0, 0)
            slot.n += 1
            if normalized(run(row.typed)) == normalized(row.stock) {
                slot.agree += 1
            } else if (misses[row.slice]?.count ?? 0) < 5 {
                misses[row.slice, default: []].append(
                    "\(row.id) \(row.typed.debugDescription) -> "
                    + "\(run(row.typed).debugDescription) stock \(row.stock.debugDescription)")
            }
            totals[row.slice] = slot
        }
        var agree = 0, n = 0
        for (slice, slot) in totals.sorted(by: { $0.key < $1.key }) {
            print("ORACLE-AGREE \(slice): \(slot.agree)/\(slot.n) "
                  + "(\(slot.agree * 100 / max(slot.n, 1))%)")
            for miss in misses[slice] ?? [] { print("  \(miss)") }
            agree += slot.agree
            n += slot.n
        }
        print("ORACLE-AGREE total: \(agree)/\(n) (\(agree * 100 / max(n, 1))%)")
        #expect(n == 400, "the oracle corpus lost rows")
    }
}
