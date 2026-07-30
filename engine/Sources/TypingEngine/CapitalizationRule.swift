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
        // Closers and emoji (plus their separating spaces) can sit between
        // the terminator and the cursor ("come over.\u{201D} ", "ok. 👍 ")
        // without breaking the boundary.
        while i > context.startIndex {
            let prev = context[context.index(before: i)]
            guard Self.closers.contains(prev) || prev.isEmojiLike || prev.isWhitespace else { break }
            i = context.index(before: i)
        }
        guard i > context.startIndex else { return false }
        switch context[context.index(before: i)] {
        case "!", "?", "\u{2026}":
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

extension Character {
    /// Emoji as rendered on the emoji keyboard: scalars with default emoji
    /// presentation, or forced emoji via VS16 (❤️). Excludes digits and
    /// other text-presentation characters that merely CAN be emoji.
    var isEmojiLike: Bool {
        unicodeScalars.contains {
            $0.properties.isEmojiPresentation || $0.value == 0xFE0F
        }
    }
}
