import PunctuationEngine

/// Decides whether the next typed letter starts a sentence and should be
/// capitalized. Pure text logic; the shift-key wiring arrives in Phase 3.
public enum CapitalizationRule {
    /// Closing marks that can sit between a sentence ender and the space
    /// ("come over.\u{201D} ") without breaking the sentence boundary.
    private static let closers: Set<Character> = [
        "\"", "\u{201D}", "'", "\u{2019}", ")", "]"
    ]

    public static func shouldCapitalize(before context: String) -> Bool {
        // Walk off trailing whitespace; a newline there means a fresh line,
        // which always starts capitalized.
        var i = context.endIndex
        var sawSeparator = false
        while i > context.startIndex {
            let prev = context.index(before: i)
            guard context[prev].isWhitespace else { break }
            if context[prev].isNewline { return true }
            sawSeparator = true
            i = prev
        }
        // Nothing but whitespace (or empty): start of text.
        if i == context.startIndex { return true }
        // No separator after the last character: the user is mid-word.
        guard sawSeparator else { return false }
        while i > context.startIndex, Self.closers.contains(context[context.index(before: i)]) {
            i = context.index(before: i)
        }
        guard i > context.startIndex else { return false }
        switch context[context.index(before: i)] {
        case "!", "?":
            return true
        case ".":
            // "e.g." / "etc." complete a token, not the sentence (AC7b) --
            // but a title ("Mr.") precedes a name, which capitalizes anyway.
            let token = trailingToken(in: context[..<i])
            return !PunctuationEngine.isKnownAbbreviation(token) ||
                PunctuationEngine.isTitleAbbreviation(token)
        default:
            return false
        }
    }

    /// The token ending at the substring's end, letters and dots only
    /// ("over." from ...come over., "e.g." from see e.g.).
    private static func trailingToken(in head: Substring) -> String {
        guard let lastOutside = head.lastIndex(where: { !($0.isLetter || $0 == ".") }) else {
            return String(head)
        }
        return String(head[head.index(after: lastOutside)...])
    }
}
