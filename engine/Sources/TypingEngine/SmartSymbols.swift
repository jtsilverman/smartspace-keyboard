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
    public static func decision(
        forTyping char: Character,
        before context: String
    ) -> TypedSymbolDecision {
        .insert(String(char))
    }
}
