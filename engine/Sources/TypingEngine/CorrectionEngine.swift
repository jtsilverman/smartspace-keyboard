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
    /// - Parameter lexicon: protected words (contact names, text
    ///   replacements) that are never corrected away, matched
    ///   case-insensitively. Phase 3 fills this from UILexicon.
    public init(checker: any SpellChecking, lexicon: Set<String> = []) {
    }

    public func decision(for context: String) -> CorrectionDecision {
        .noChange
    }
}
