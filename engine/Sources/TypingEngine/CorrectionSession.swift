/// Per-keyboard-session correction memory: which correction can still be
/// undone, and which words the user has un-corrected and must never be
/// auto-corrected again (the correction-loop guard).
public struct CorrectionSession: Sendable {
    private var protectedWords: Set<String> = []
    private var last: (original: String, corrected: String)?

    public init() {
    }

    /// Records an applied correction so a later undo-tap can revert it, and
    /// so the next word can revise it: a fragment corrected at its own space
    /// ("tomo" -> "too") is still the fragment when "rrow" follows.
    public mutating func recordCorrection(original: String, corrected: String) {
        last = (original, corrected)
    }

    /// The most recent correction, until it is undone.
    public var lastCorrection: (original: String, corrected: String)? { last }

    /// Undoes the most recent correction: returns the original word the
    /// keyboard should restore and protects it from re-correction for the
    /// rest of the session. Nil when there is nothing to undo.
    public mutating func undoLast() -> String? {
        guard let original = last?.original else { return nil }
        last = nil
        protectedWords.insert(original.lowercased())
        return original
    }

    /// Marks a word never-to-be-corrected without an undo round-trip --
    /// the verbatim "keep what I typed" tap in the completion bar.
    public mutating func protect(_ word: String) {
        protectedWords.insert(word.lowercased())
    }

    /// Whether the user has un-corrected this word (case-insensitive).
    public func isProtected(_ word: String) -> Bool {
        protectedWords.contains(word.lowercased())
    }
}
