/// What lands in the text when a symbol key is typed.
public enum TypedSymbolDecision: Equatable, Sendable {
    case insert(String)
    /// Replace `count` characters before the cursor with `with`
    /// (the -- to em-dash collapse).
    case replacePreceding(count: Int, with: String)
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
            return .insert(opensQuote(context) ? "\u{201C}" : "\u{201D}")
        case "'":
            return .insert(opensQuote(context) ? "\u{2018}" : "\u{2019}")
        case "-" where context.last == "-":
            return .replacePreceding(count: 1, with: "\u{2014}")
        default:
            return .insert(String(char))
        }
    }

    private static func opensQuote(_ context: String) -> Bool {
        guard let last = context.last else { return true }
        return last.isWhitespace || Self.openers.contains(last)
    }
}
