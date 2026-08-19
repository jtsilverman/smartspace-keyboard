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
    /// The caller's lexicon (UILexicon: contacts, text replacements) unions
    /// with the shipped TextingLexicon; both are never-correct words.
    public init(checker: any SpellChecking, lexicon: Set<String> = []) {
        self.checker = checker
        self.lexicon = TextingLexicon.words.union(lexicon.map { $0.lowercased() })
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
        // Sentence start here includes any trailing period ("Ave. Dont"):
        // a smart-space period after an abbreviation deliberately ended
        // the sentence even though CapitalizationRule reads it as one.
        let prefix = String(context.dropLast(word.count))
        let sentenceStart = CapitalizationRule.shouldCapitalize(before: prefix)
            || prefix.last(where: { !$0.isWhitespace }).map { ".!?".contains($0) } == true
        if word.first?.isUppercase == true, word.dropFirst().contains(where: \.isLowercase),
           !sentenceStart {
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
        // "Ill"/"Id" at a sentence start are the autocap products of typing
        // an I-contraction (ill be there -> Ill); lowercase and mid-sentence
        // forms keep the homograph protection above and in ContractionRule.
        if let fixed = ["Ill": "I\u{2019}ll", "Id": "I\u{2019}d"][word] {
            return .correct(to: fixed, alternatives: [])
        }
        // Calendar names typed lowercase capitalize (coming saturday ->
        // Saturday); curated list, march/may homographs excluded.
        if let fixed = CalendarRule.transform(word) {
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
        var suggestions = checker.suggestions(for: word).map { recased($0, like: word) }
        // Re-rank by edit distance, then English word frequency, then the
        // checker's own order as the deterministic last tiebreak. The order a
        // checker hands up is not trusted: UITextChecker returned its guesses
        // alphabetically, and DictionarySpellChecker's scan is capped at eight.
        let lower = word.lowercased()
        suggestions = suggestions.enumerated()
            .map { (index: $0.offset, text: $0.element,
                    distance: typoDistance(from: lower, to: $0.element.lowercased()),
                    rank: WordRank.rank($0.element)) }
            .sorted {
                if $0.distance != $1.distance { return $0.distance < $1.distance }
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                return $0.index < $1.index
            }
            .map(\.text)
        // A suggestion that is the typed word merely recased (jake -> Jake)
        // IS the word; it outranks any letter-changing suggestion.
        if let i = suggestions.firstIndex(where: { $0.lowercased() == word.lowercased() }),
           i > 0 {
            suggestions.insert(suggestions.remove(at: i), at: 0)
        }
        guard let top = suggestions.first else { return .noChange }
        // A top suggestion far from the typed word is the checker guessing
        // at a word it doesn't know (names, slang, loanwords) -- rejecting
        // it beats mangling. Damerau (transposition = 1 edit), so wierd ->
        // weird stays a near fix.
        guard EditDistance.damerau(word.lowercased(), top.lowercased())
                <= max(1, word.count / 4) else { return .noChange }
        return .correct(to: top, alternatives: Array(suggestions.dropFirst()))
    }

    /// Edit distance with one typo-shape refinement: a candidate that only
    /// restores a dropped double letter (realy -> really) is closer than a
    /// generic single edit (realy -> real), because dropping one of a
    /// doubled pair is the more common slip.
    private func typoDistance(from word: String, to candidate: String) -> Double {
        let base = Double(EditDistance.damerau(word, candidate))
        return base == 1 && restoresDoubledLetter(word: word, candidate: candidate)
            ? 0.5 : base
    }

    /// True when removing one of a doubled pair in the candidate yields the
    /// typed word exactly.
    private func restoresDoubledLetter(word: String, candidate: String) -> Bool {
        guard candidate.count == word.count + 1 else { return false }
        let c = Array(candidate)
        for i in 1..<c.count where c[i] == c[i - 1] {
            var trimmed = c
            trimmed.remove(at: i)
            if String(trimmed) == word { return true }
        }
        return false
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
