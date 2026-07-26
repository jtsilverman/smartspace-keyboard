/// Extracts the word just committed from the text before the cursor, so the
/// correction pipeline knows what to judge. Kept separate from
/// PunctuationEngine's tokenizer, which lowercases and strips apostrophes --
/// a correction needs the raw word exactly as typed.
public enum WordBoundary {
    /// The trailing word of `context` with casing and apostrophes intact,
    /// or nil when nothing correctable was committed.
    public static func lastWord(in context: String) -> String? {
        nil
    }
}
