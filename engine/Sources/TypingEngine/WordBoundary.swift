/// Extracts the word just committed from the text before the cursor, so the
/// correction pipeline knows what to judge. Kept separate from
/// PunctuationEngine's tokenizer, which lowercases and strips apostrophes --
/// a correction needs the raw word exactly as typed.
public enum WordBoundary {
    /// The trailing word of `context` with casing and apostrophes intact,
    /// or nil when nothing correctable was committed: empty context, context
    /// already ending in whitespace, or a trailing token carrying digits or
    /// URL/address characters (correcting those silently mangles data the
    /// user typed on purpose).
    public static func lastWord(in context: String) -> String? {
        guard let lastChar = context.last, !lastChar.isWhitespace else { return nil }
        let token = context.split(whereSeparator: { $0.isWhitespace }).last!
        guard !token.contains(where: { $0.isNumber }) else { return nil }
        // Handles and hashtags are addresses; the sigil marks the whole
        // token untouchable, not just its letters.
        guard token.first != "@", token.first != "#" else { return nil }
        guard let firstLetter = token.firstIndex(where: { $0.isLetter }),
              let lastLetter = token.lastIndex(where: { $0.isLetter }) else { return nil }
        let word = token[firstLetter...lastLetter]
        guard word.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "\u{2019}" || $0 == "-" }) else {
            return nil
        }
        return String(word)
    }
}
