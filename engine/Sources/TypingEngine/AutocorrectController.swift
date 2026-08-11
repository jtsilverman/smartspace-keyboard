/// Orchestrates the suggestion bar for the live keyboard: word commits
/// become replace-or-keep decisions with an undoable correction bar, and
/// mid-word typing fills the bar with the typed word plus dictionary
/// completions. One authority for what the bar shows; the keyboard renders
/// it and performs the text edits.
public struct AutocorrectController: Sendable {
    /// What the keyboard should do with the word just committed.
    public enum Commit: Equatable, Sendable {
        case keep
        /// Replace `original` (the last word in the document) with
        /// `corrected`. `alternatives` fill the remaining bar slots.
        case replace(original: String, corrected: String, alternatives: [String])
    }

    /// What the suggestion bar currently shows.
    public enum BarContent: Equatable, Sendable {
        case empty
        /// Post-commit correction: slot 0 = the typed original (tap to
        /// undo), then alternatives (tap to swap).
        case correction(slots: [String])
        /// Mid-word: slot 0 = the word as typed (tap to keep + protect),
        /// then follow slots (tap to finish the word). When `correction`
        /// is set, a commit would correct: slot 0 renders in quotation
        /// marks (stock's tell), completions[0] IS the correction and
        /// draws the stock highlight pill.
        case completions(typed: String, completions: [String], correction: String?)
    }

    /// What a suggestion-bar tap means for the document.
    public enum BarAction: Equatable, Sendable {
        case none
        /// Replace `corrected` (currently in the document) with `original`;
        /// the word is now protected from re-correction this session.
        case undo(original: String, corrected: String)
        /// Replace `from` (currently in the document) with `to`.
        case swap(from: String, to: String)
        /// Commit the partial word exactly as typed (add the space) and
        /// protect it from autocorrect this session.
        case acceptTyped(word: String)
        /// Replace the partial `from` with the completion `to` (plus space).
        case complete(from: String, to: String)
    }

    /// The bar shows at most the original/typed plus two follow slots.
    private static let maxAlternatives = 2

    /// True when typing `char` ends the current word and must commit any
    /// pending correction, like space and return do on their own paths.
    /// Apostrophe and hyphen stay word characters ("don't", "well-known").
    public static func isCommitDelimiter(_ char: Character) -> Bool {
        commitDelimiters.contains(char)
    }

    private static let commitDelimiters: Set<Character> = [".", ",", "!", "?", ":", ";"]

    private enum State: Sendable {
        case idle
        case correction(original: String, corrected: String, alternatives: [String])
        case typing(typed: String, completions: [String], quoted: Bool)
    }

    private let checker: any SpellChecking
    private var engine: CorrectionEngine
    private var session = CorrectionSession()
    private var state: State = .idle

    public init(checker: any SpellChecking, lexicon: Set<String> = []) {
        self.checker = checker
        engine = CorrectionEngine(checker: checker, lexicon: lexicon)
    }

    /// Adopts a lexicon that arrived after init (UILexicon is async).
    /// Only the decision engine changes; session protection and the active
    /// bar survive.
    public mutating func updateLexicon(_ lexicon: Set<String>) {
        engine = CorrectionEngine(checker: checker, lexicon: lexicon)
    }

    public var barContent: BarContent {
        switch state {
        case .idle:
            return .empty
        case .correction(let original, _, let alternatives):
            return .correction(slots: [original] + alternatives)
        case .typing(let typed, let completions, _):
            return .completions(typed: typed, completions: completions, correction: nil)
        }
    }

    /// The word the active correction currently has in the document (tracks
    /// swaps). The keyboard verifies the document still ends with this before
    /// editing; nil when no correction is active.
    public var currentCorrected: String? {
        guard case .correction(_, let corrected, _) = state else { return nil }
        return corrected
    }

    /// A word was committed (space or return). Decides keep vs replace and
    /// refills or clears the bar.
    public mutating func wordCommitted(context: String) -> Commit {
        switch engine.decision(for: context, session: session) {
        case .noChange:
            state = .idle
            return .keep
        case .correct(let to, let alternatives):
            guard let original = WordBoundary.lastWord(in: context) else {
                state = .idle
                return .keep
            }
            let capped = Array(alternatives.prefix(Self.maxAlternatives))
            session.recordCorrection(original: original)
            state = .correction(original: original, corrected: to, alternatives: capped)
            return .replace(original: original, corrected: to, alternatives: capped)
        }
    }

    /// Mid-word bar refresh: a non-empty partial word takes the bar over
    /// with typed + completions (a fresh correction yields to the next
    /// word's first letter); an empty partial only clears stale typing
    /// state, never a correction (its undo window survives the commit
    /// space).
    public mutating func typingUpdate(context: String) {
        guard let partial = Self.partialWord(in: context) else {
            if case .typing = state { state = .idle }
            return
        }
        let completions = Array(checker.completions(for: partial).prefix(Self.maxAlternatives))
        let quoted: Bool
        if case .correct = engine.decision(for: context, session: session) {
            quoted = true
        } else {
            quoted = false
        }
        state = .typing(typed: partial, completions: completions, quoted: quoted)
    }

    /// The word actively being typed: the trailing run of letters and word
    /// punctuation. Unlike WordBoundary.lastWord, a trailing "!" or digit
    /// means NO partial -- "hi!" must not resurrect completions for "hi".
    private static func partialWord(in context: String) -> String? {
        var run: [Character] = []
        for char in context.reversed() {
            guard char.isLetter || char == "'" || char == "\u{2019}" || char == "-" else { break }
            run.append(char)
        }
        guard !run.isEmpty else { return nil }
        return String(run.reversed())
    }

    /// Correction state: slot 0 undoes, others swap. Typing state: slot 0
    /// accepts the word as typed (and protects it), others complete.
    public mutating func barTapped(slot: Int) -> BarAction {
        switch state {
        case .idle:
            return .none
        case .correction(let original, let corrected, var alternatives):
            guard slot >= 0, slot <= alternatives.count else { return .none }
            if slot == 0 {
                guard let restored = session.undoLast() else { return .none }
                state = .idle
                return .undo(original: restored, corrected: corrected)
            }
            let chosen = alternatives[slot - 1]
            alternatives[slot - 1] = corrected
            state = .correction(original: original, corrected: chosen,
                                alternatives: alternatives)
            return .swap(from: corrected, to: chosen)
        case .typing(let typed, let completions, _):
            guard slot >= 0, slot <= completions.count else { return .none }
            state = .idle
            if slot == 0 {
                session.protect(typed)
                return .acceptTyped(word: typed)
            }
            return .complete(from: typed, to: completions[slot - 1])
        }
    }

    /// The bar's pending edits are no longer valid (cursor moved, text
    /// changed under it): clear it. A closed correction loses its undo
    /// window (undo is only reachable through an active bar); protection
    /// (undone words) is untouched.
    public mutating func invalidateBar() {
        state = .idle
    }

    /// Backspace edits the tail the bar's content lives in.
    public mutating func backspace() {
        invalidateBar()
    }
}
