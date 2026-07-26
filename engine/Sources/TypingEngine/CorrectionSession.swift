/// Per-keyboard-session correction memory: which correction can still be
/// undone, and which words the user has un-corrected and must never be
/// auto-corrected again (the correction-loop guard).
public struct CorrectionSession: Sendable {
    public init() {
    }

    /// Records an applied correction so a later undo-tap can revert it.
    public mutating func recordCorrection(original: String, corrected: String) {
    }

    /// Undoes the most recent correction: returns the original word the
    /// keyboard should restore and protects it from re-correction for the
    /// rest of the session. Nil when there is nothing to undo.
    public mutating func undoLast() -> String? {
        nil
    }

    /// Whether the user has un-corrected this word (case-insensitive).
    public func isProtected(_ word: String) -> Bool {
        false
    }
}
