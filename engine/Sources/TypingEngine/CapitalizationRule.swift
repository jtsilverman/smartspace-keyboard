import PunctuationEngine

/// Decides whether the next typed letter starts a sentence and should be
/// capitalized. Pure text logic; the shift-key wiring arrives in Phase 3.
public enum CapitalizationRule {
    public static func shouldCapitalize(before context: String) -> Bool {
        false
    }
}
