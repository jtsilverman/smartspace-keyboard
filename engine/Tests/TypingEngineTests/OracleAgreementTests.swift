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
///
/// The rows fall into two halves by row number (specs/autocorrect-loop.md):
/// even rows are dev and every dev miss prints; odd rows are test and only
/// the count prints. A context pair shares its number, so both sentences of
/// a pair sit in one half. The loop's proposer reads dev and is scored on
/// both, and a test half that drops while dev rises is the overfit signal.
@Suite struct OracleAgreementTests {

    /// "dev" for an even row number, "test" for an odd one.
    static func half(of id: String) -> String {
        let digits = id.drop(while: { !$0.isNumber }).prefix(while: \.isNumber)
        return (Int(digits) ?? 0) % 2 == 0 ? "dev" : "test"
    }

    /// Types a row the way the keyboard does: each space commits the word
    /// before it through the bar controller, which owns the session memory a
    /// join reads, and the replace it hands back rewrites the field.
    private func run(_ typed: String) -> String {
        var controller = AutocorrectController(checker: DictionarySpellChecker())
        var field = ""
        for word in typed.split(separator: " ", omittingEmptySubsequences: true) {
            field += (field.isEmpty ? "" : " ") + word
            if case .replace(let original, let corrected, _) = controller.wordCommitted(context: field) {
                field = String(field.dropLast(original.count)) + corrected
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
        var misses: [String] = []
        for row in oracleAnswers {
            let half = Self.half(of: row.id)
            for key in [row.slice, "\(row.slice)/\(half)"] {
                var slot = totals[key] ?? (0, 0)
                slot.n += 1
                if normalized(run(row.typed)) == normalized(row.stock) { slot.agree += 1 }
                totals[key] = slot
            }
            if half == "dev", normalized(run(row.typed)) != normalized(row.stock) {
                misses.append("ORACLE-MISS \(row.id) \(row.typed.debugDescription) -> "
                    + "\(run(row.typed).debugDescription) stock \(row.stock.debugDescription)")
            }
        }
        var agree = (all: 0, dev: 0, test: 0), n = (all: 0, dev: 0, test: 0)
        for (key, slot) in totals.sorted(by: { $0.key < $1.key }) {
            print("ORACLE-AGREE \(key): \(slot.agree)/\(slot.n) "
                  + "(\(slot.agree * 100 / max(slot.n, 1))%)")
            if key.hasSuffix("/dev") { agree.dev += slot.agree; n.dev += slot.n }
            else if key.hasSuffix("/test") { agree.test += slot.agree; n.test += slot.n }
            else { agree.all += slot.agree; n.all += slot.n }
        }
        print("ORACLE-AGREE total/dev: \(agree.dev)/\(n.dev) (\(agree.dev * 100 / max(n.dev, 1))%)")
        print("ORACLE-AGREE total/test: \(agree.test)/\(n.test) (\(agree.test * 100 / max(n.test, 1))%)")
        print("ORACLE-AGREE total: \(agree.all)/\(n.all) (\(agree.all * 100 / max(n.all, 1))%)")
        for miss in misses { print(miss) }
        #expect(n.all == 400, "the oracle corpus lost rows")
    }

    @Test func aContextPairSharesOneHalf() {
        #expect(Self.half(of: "ctx-003a") == Self.half(of: "ctx-003b"))
        #expect(Self.half(of: "ctx-003a") == "test")
        #expect(Self.half(of: "nosp-018") == "dev")
    }
}
