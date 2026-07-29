/// What lands in the text when a symbol key is typed.
public enum TypedSymbolDecision: Equatable, Sendable {
    case insert(String)
    /// Replace the character before the cursor with `with`
    /// (the -- to em-dash collapse).
    case replacePrevious(with: String)
    /// Replace the last `n` characters before the cursor with `with`
    /// (the ... to ellipsis collapse).
    case replaceLast(Int, with: String)
}

/// Curly-quote and em-dash conversion for typed symbols -- the pair behind
/// the single smart quotes/dashes toggle. Everything else passes through.
public enum SmartSymbols {
    /// Positions where a typed quote opens rather than closes: start of
    /// text, after whitespace, or after an opening bracket/quote.
    private static let openers: Set<Character> = [
        "(", "[", "{", "\u{201C}", "\u{2018}"
    ]

    public static func decision(
        forTyping char: Character,
        before context: String
    ) -> TypedSymbolDecision {
        switch char {
        case "\"":
            if isPrimePosition(context, closing: "\u{201C}") { return .insert("\"") }
            return .insert(opensQuote(context) ? "\u{201C}" : "\u{201D}")
        case "'":
            if isPrimePosition(context, closing: "\u{2018}") { return .insert("'") }
            return .insert(opensQuote(context) ? "\u{2018}" : "\u{2019}")
        case "-" where context.last == "-":
            // Em dash between words (so--anyway) or opening a message-start
            // aside (--and another thing). After a space it's a CLI flag
            // (--save-dev); after another hyphen it's a divider run.
            let beforeHyphen = context.dropLast().last
            guard beforeHyphen == nil || beforeHyphen?.isLetter == true
                    || beforeHyphen?.isNumber == true else {
                return .insert("-")
            }
            return .replacePrevious(with: "\u{2014}")
        case let d where d.isNumber && context.last == "\u{2018}":
            // A digit after a freshly opened single quote reveals an elision
            // apostrophe ('90s), not a quotation -- retro-flip it.
            return .replaceLast(1, with: "\u{2019}" + String(d))
        case "." where context.hasSuffix("..") && !context.hasSuffix("..."):
            // Third dot collapses to a single-char ellipsis. Requiring
            // exactly two trailing dots keeps ranges (1..10 typed dot by
            // dot triggers only on a third) from over-collapsing runs.
            return .replaceLast(2, with: "\u{2026}")
        default:
            return .insert(String(char))
        }
    }

    private static func opensQuote(_ context: String) -> Bool {
        guard let last = context.last else { return true }
        return last.isWhitespace || Self.openers.contains(last)
    }

    /// A quote directly after a digit is a prime mark (5'10", 6') and stays
    /// straight -- unless a same-kind opening quote is pending, where
    /// closing the quotation wins ("i'm 25" + quote closes).
    private static func isPrimePosition(_ context: String, closing opener: Character) -> Bool {
        guard context.last?.isNumber == true else { return false }
        let closer: Character = opener == "\u{201C}" ? "\u{201D}" : "\u{2019}"
        var pending = 0
        for ch in context {
            if ch == opener { pending += 1 }
            if ch == closer { pending -= 1 }
        }
        return pending <= 0
    }
}
