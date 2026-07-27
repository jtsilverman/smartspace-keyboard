/// Orchestrates autocorrect for the live keyboard: turns word commits into
/// replace-or-keep decisions and suggestion-bar taps into undo/swap edits.
/// Pure logic -- the keyboard performs the text edits and renders the bar.
public struct AutocorrectController: Sendable {
    /// What the keyboard should do with the word just committed.
    public enum Commit: Equatable, Sendable {
        case keep
        /// Replace `original` (the last word in the document) with
        /// `corrected`. `alternatives` fill the remaining bar slots.
        case replace(original: String, corrected: String, alternatives: [String])
    }

    /// What a suggestion-bar tap means for the document.
    public enum BarAction: Equatable, Sendable {
        case none
        /// Replace `corrected` (currently in the document) with `original`;
        /// the word is now protected from re-correction this session.
        case undo(original: String, corrected: String)
        /// Replace `from` (currently in the document) with `to`.
        case swap(from: String, to: String)
    }

    /// The bar shows at most the original plus two alternatives.
    private static let maxAlternatives = 2

    private var engine: CorrectionEngine
    private var session = CorrectionSession()
    /// The correction currently shown in the bar; nil means the bar is empty.
    private var active: (original: String, corrected: String, alternatives: [String])?

    public init(checker: any SpellChecking, lexicon: Set<String> = []) {
        engine = CorrectionEngine(checker: checker, lexicon: lexicon)
    }

    /// Bar slots to render: the original word first, then alternatives.
    /// Empty when no correction is undoable.
    public var barSlots: [String] {
        guard let active else { return [] }
        return [active.original] + active.alternatives
    }

    /// A word was committed (space or return). Decides keep vs replace and
    /// refills or clears the bar.
    public mutating func wordCommitted(context: String) -> Commit {
        switch engine.decision(for: context, session: session) {
        case .noChange:
            active = nil
            return .keep
        case .correct(let to, let alternatives):
            guard let original = WordBoundary.lastWord(in: context) else {
                active = nil
                return .keep
            }
            let capped = Array(alternatives.prefix(Self.maxAlternatives))
            session.recordCorrection(original: original)
            active = (original, to, capped)
            return .replace(original: original, corrected: to, alternatives: capped)
        }
    }

    /// Slot 0 undoes the correction; other slots swap in that alternative
    /// (the displaced word becomes an alternative so the user can swap back).
    public mutating func barTapped(slot: Int) -> BarAction {
        guard var current = active, slot >= 0, slot <= current.alternatives.count
        else { return .none }
        if slot == 0 {
            guard let original = session.undoLast() else { return .none }
            active = nil
            return .undo(original: original, corrected: current.corrected)
        }
        let chosen = current.alternatives[slot - 1]
        let displaced = current.corrected
        current.alternatives[slot - 1] = displaced
        current.corrected = chosen
        active = current
        return .swap(from: displaced, to: chosen)
    }

    /// Backspace edits the tail the correction lives in: clear the bar,
    /// which also closes the undo window (undo is only reachable through
    /// an active bar). Protection (undone words) is untouched.
    public mutating func backspace() {
        active = nil
    }
}
