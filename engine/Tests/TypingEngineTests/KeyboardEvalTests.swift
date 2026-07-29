import Foundation
import Testing
@testable import TypingEngine

/// Keyboard-wide blind eval v4 (specs/keyboard-eval.md): capitalization and
/// contraction/smart-symbol sets scored against the pure engine rules.
/// Dev misses may be studied for invariant-first fixes; test halves report
/// aggregate numbers only.

private func unescapeNewlines(_ s: String) -> String {
    s.replacingOccurrences(of: "\\n", with: "\n")
}

// MARK: - Capitalization

private func scoreCap(_ rows: [CapCase], name: String, printMisses: Bool) -> Int {
    var hits = 0
    var missesBySub: [String: [String]] = [:]
    for r in rows {
        let context = unescapeNewlines(r.context)
        // standalone-i rows grade the i -> I commit fix (autocorrect path),
        // not the shift state; route them to the rule that owns it.
        let got: Bool
        if r.sub == "standalone-i" {
            got = WordBoundary.lastWord(in: context).flatMap(ContractionRule.transform) == "I"
        } else {
            got = CapitalizationRule.shouldCapitalize(before: context)
        }
        if got == r.expectCap {
            hits += 1
        } else {
            missesBySub[r.sub, default: []].append(r.id)
        }
    }
    let pct = rows.isEmpty ? 0 : hits * 100 / rows.count
    print("[\(name)] \(hits)/\(rows.count) (\(pct)%)")
    if printMisses {
        for (sub, ids) in missesBySub.sorted(by: { $0.value.count > $1.value.count }) {
            print("  miss \(sub): \(ids.count) \(ids.joined(separator: " "))")
        }
    }
    return hits
}

@Test func capEvalDevReport() {
    let rows = capCorpus.filter { $0.half == "dev" }
    #expect(scoreCap(rows, name: "CAP DEV", printMisses: true) > 0)
}

@Test func capEvalTestReport() {
    let rows = capCorpus.filter { $0.half == "test" }
    #expect(scoreCap(rows, name: "CAP TEST", printMisses: false) > 0)
}

// MARK: - Symbols / contractions

private struct NoopChecker: SpellChecking {
    func suggestions(for word: String) -> [String] { [] }
}

/// Join a row's context and typed unit the way the field would hold them:
/// a typed unit starting with a word character is a new word (space join);
/// one starting with punctuation continues adjacently (quote-close,
/// bare-dash rows). Typed units carrying their own leading space keep it.
private func joinedContext(_ context: String, typed: String) -> String {
    guard !context.isEmpty, context.last?.isWhitespace != true,
          let first = typed.first, !first.isWhitespace else { return context }
    return (first.isLetter || first.isNumber) ? context + " " : context
}

/// Simulate the live typing path for one typed unit: each character routes
/// through SmartSymbols (quotes, -- collapse); every space commits the text
/// through CorrectionEngine (contraction fixes + guards, no spell
/// suggestions), mirroring the keyboard's space-commit order; the unit's end
/// is the final commit.
func simulateTypedUnit(context: String, typed: String) -> String {
    let engine = CorrectionEngine(checker: NoopChecker())
    var text = joinedContext(context, typed: typed)

    func commit() {
        if case .correct(let to, _) = engine.decision(for: text),
           let word = WordBoundary.lastWord(in: text) {
            text = String(text.dropLast(word.count)) + to
        }
    }

    for ch in typed {
        if ch == " " {
            commit()
            text += " "
            continue
        }
        switch SmartSymbols.decision(forTyping: ch, before: text) {
        case .insert(let s):
            text += s
        case .replacePrevious(let s):
            text = String(text.dropLast()) + s
        case .replaceLast(let n, let s):
            text = String(text.dropLast(n)) + s
        }
    }
    commit()
    return text
}

private func scoreSymbols(_ rows: [SymbolCase], name: String, printMisses: Bool) -> Int {
    var hits = 0
    var missesBySub: [String: [String]] = [:]
    for r in rows {
        let context = unescapeNewlines(r.context)
        let got = simulateTypedUnit(context: context, typed: r.typed)
        if got == joinedContext(context, typed: r.typed) + r.expected {
            hits += 1
        } else {
            missesBySub[r.sub, default: []].append(r.id)
        }
    }
    let pct = rows.isEmpty ? 0 : hits * 100 / rows.count
    print("[\(name)] \(hits)/\(rows.count) (\(pct)%)")
    if printMisses {
        for (sub, ids) in missesBySub.sorted(by: { $0.value.count > $1.value.count }) {
            print("  miss \(sub): \(ids.count) \(ids.joined(separator: " "))")
        }
    }
    return hits
}

@Test func symbolEvalDevReport() {
    let rows = symbolCorpus.filter { $0.half == "dev" }
    #expect(scoreSymbols(rows, name: "SYMBOLS DEV", printMisses: true) > 0)
}

@Test func symbolEvalTestReport() {
    let rows = symbolCorpus.filter { $0.half == "test" }
    #expect(scoreSymbols(rows, name: "SYMBOLS TEST", printMisses: false) > 0)
}
