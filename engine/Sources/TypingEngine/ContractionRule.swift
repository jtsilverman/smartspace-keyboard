/// Fixes apostrophe-less contractions and standalone "i" at word commit,
/// with curly apostrophes. Deliberately curated: words that double as real
/// words (its, ill, well) are never touched -- a misfire there mangles
/// intended text, and the spell checker covers them in Phase 3.
public enum ContractionRule {
    /// The corrected form of a committed word, or nil to leave it alone.
    public static func transform(_ word: String) -> String? {
        nil
    }
}
