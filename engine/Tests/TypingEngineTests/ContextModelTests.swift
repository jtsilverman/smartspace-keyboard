import Testing
@testable import TypingEngine

/// The student (specs/autocorrect-loop.md, unit 5): a next-word model the
/// engine maps from Resources/contextmodel.bin, behind the same ContextScoring
/// seam as the pair table. The pilot question is one number: on the oracle's
/// context and nospace dev halves, does the student agree with stock more
/// often than the pair table does?
@Suite struct ContextModelTests {
    @Test func aKnownWordAfterAKnownWordHasALikelihoodAndAnUnknownWordHasNone() {
        let model = ContextModel()
        let than = model.likelihood(of: "than", after: ["more"])
        #expect(than != nil)
        #expect(than! > 0 && than! <= 1)
        #expect(model.likelihood(of: "xylophonium", after: ["more"]) == nil)
    }

    @Test func theModelReadsTheSentenceNotJustTheLastWord() {
        let model = ContextModel()
        let short = model.likelihood(of: "you", after: ["see"])
        let long = model.likelihood(of: "you", after: ["i", "will", "see"])
        #expect(short != nil && long != nil)
        #expect(short != long)
    }

    /// Types the context and nospace dev-half rows through the controller with
    /// each context model and prints the agreement side by side. Report-style:
    /// the pilot's verdict is read off the numbers, never asserted, because a
    /// student that loses is a finding the spec sends back to Jake.
    @Test func pilotAgreementAgainstThePairTable() {
        func run(_ typed: String, _ context: any ContextScoring) -> String {
            var controller = AutocorrectController(checker: DictionarySpellChecker(), contextModel: context)
            var field = ""
            for word in typed.split(separator: " ", omittingEmptySubsequences: true) {
                field += (field.isEmpty ? "" : " ") + word
                if case .replace(let original, let corrected, _) = controller.wordCommitted(context: field) {
                    field = String(field.dropLast(original.count)) + corrected
                }
            }
            return field.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        }
        let rows = oracleAnswers.filter {
            ($0.slice == "context" || $0.slice == "nospace") && OracleAgreementTests.half(of: $0.id) == "dev"
        }
        for (name, model) in [("pairs", WordPairModel() as any ContextScoring), ("student", ContextModel())] {
            var agree: [String: (Int, Int)] = [:]
            for row in rows {
                var slot = agree[row.slice] ?? (0, 0)
                slot.1 += 1
                if run(row.typed, model) == row.stock.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
                    .trimmingCharacters(in: .whitespaces) { slot.0 += 1 }
                agree[row.slice] = slot
            }
            for (slice, (a, n)) in agree.sorted(by: { $0.key < $1.key }) {
                print("PILOT \(name) \(slice)/dev: \(a)/\(n)")
            }
        }
        #expect(rows.count == 100)
    }
}
