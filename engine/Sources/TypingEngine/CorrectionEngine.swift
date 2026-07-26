/// The seam between pure correction logic and the platform spell checker.
/// Tests supply a fake; Phase 3 wraps UITextChecker behind this so the
/// decision rules never import UIKit.
public protocol SpellChecking: Sendable {
    /// Ranked suggestions for a misspelled word, best first.
    /// Empty means the word is spelled correctly.
    func suggestions(for word: String) -> [String]
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
        // All-caps words are acronyms more often than typos; correcting
        // them mangles deliberate input.
        let letters = word.filter(\.isLetter)
        if letters.count >= 2, letters.allSatisfy(\.isUppercase) { return .noChange }
        let suggestions = checker.suggestions(for: word).map { recased($0, like: word) }
        guard let top = suggestions.first else { return .noChange }
        return .correct(to: top, alternatives: Array(suggestions.dropFirst()))
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
