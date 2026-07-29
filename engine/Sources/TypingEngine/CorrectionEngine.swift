/// The seam between pure correction logic and the platform spell checker.
/// Tests supply a fake; Phase 3 wraps UITextChecker behind this so the
/// decision rules never import UIKit.
public protocol SpellChecking: Sendable {
    /// Ranked suggestions for a misspelled word, best first.
    /// Empty means the word is spelled correctly.
    func suggestions(for word: String) -> [String]

    /// Dictionary completions for a partial word ("keyb" -> keyboard...).
    /// Defaulted so suggestion-only checkers (and fakes) stay source-stable.
    func completions(for prefix: String) -> [String]
}

extension SpellChecking {
    public func completions(for prefix: String) -> [String] { [] }
}

/// What the keyboard should do with the word just committed.
public enum CorrectionDecision: Equatable, Sendable {
    case noChange
    case correct(to: String, alternatives: [String])
}

/// Decides whether the word just committed gets replaced with the checker's
/// top suggestion.
public struct CorrectionEngine: Sendable {
    private let checker: any SpellChecking
    private let lexicon: Set<String>

    /// - Parameter lexicon: protected words (contact names, text
    ///   replacements) that are never corrected away, matched
    ///   case-insensitively. Phase 3 fills this from UILexicon.
    public init(checker: any SpellChecking, lexicon: Set<String> = []) {
        self.checker = checker
        self.lexicon = Set(lexicon.map { $0.lowercased() })
    }

    /// - Parameter session: undo memory; a word the user has un-corrected
    ///   in this session is never corrected again.
    public func decision(
        for context: String,
        session: CorrectionSession = CorrectionSession()
    ) -> CorrectionDecision {
        guard let word = WordBoundary.lastWord(in: context) else { return .noChange }
        guard !lexicon.contains(word.lowercased()) else { return .noChange }
        guard !session.isProtected(word) else { return .noChange }
        // A capitalized word mid-sentence is a proper noun (names, brands,
        // Professor Cant); its capital came from the user, not autocap, so
        // no rewrite of any kind -- contraction fixes included. At a
        // sentence start the capital IS autocap and typos still fix.
        if word.first?.isUppercase == true, word.dropFirst().contains(where: \.isLowercase),
           !CapitalizationRule.shouldCapitalize(before: String(context.dropLast(word.count))) {
            return .noChange
        }
        // Curated contraction fixes are deterministic and outrank the
        // checker AND the acronym guard (DONT is a shouted contraction,
        // not an acronym). Only when the fix actually differs -- a phantom
        // I -> I correction would put an undo slot in the bar that, tapped,
        // protects "i" and kills the fix for the session.
        if let fixed = ContractionRule.transform(word), fixed != word {
            return .correct(to: fixed, alternatives: [])
        }
        // All-caps words are acronyms more often than typos; correcting
        // them mangles deliberate input.
        let letters = word.filter(\.isLetter)
        if letters.count >= 2, letters.allSatisfy(\.isUppercase) { return .noChange }
        // Two-letter tokens are texting shortforms (gn, rn, ty, np) and
        // letter runs of 3+ are deliberate elongation (sooo, plsss); the
        // checker's guesses for both mangle intended text.
        if word.count <= 2 { return .noChange }
        if hasLetterRun(word, of: 3) { return .noChange }
        let suggestions = checker.suggestions(for: word).map { recased($0, like: word) }
        guard let top = suggestions.first else { return .noChange }
        return .correct(to: top, alternatives: Array(suggestions.dropFirst()))
    }

    private func hasLetterRun(_ word: String, of length: Int) -> Bool {
        var run = 1
        var prev: Character?
        for ch in word.lowercased() {
            run = (ch == prev) ? run + 1 : 1
            if run >= length { return true }
            prev = ch
        }
        return false
    }

    /// A word typed with a leading capital keeps it through the correction.
    /// A suggestion carrying any capital of its own (iPhone, McDonald's)
    /// already knows its casing and is passed through untouched.
    private func recased(_ suggestion: String, like word: String) -> String {
        guard word.first?.isUppercase == true,
              !suggestion.contains(where: \.isUppercase),
              let first = suggestion.first else {
            return suggestion
        }
        return first.uppercased() + suggestion.dropFirst()
    }
}
