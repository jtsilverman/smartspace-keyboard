/// One possible "what comes next" insertion for a double-space, e.g. "." or "?".
/// Text-shaped (not an enum of sentence-enders) so future candidates like an
/// opening quote can join without changing the interface.
public struct Candidate: Equatable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

/// Decides what a double-space should insert, given the sentence typed so far.
public struct PunctuationEngine: Sendable {
    private static let whWords: Set<Substring> = [
        "how", "what", "why", "when", "where", "who", "whose", "which"
    ]

    public init() {}

    /// Returns candidates ranked best-first for the text before the cursor.
    public func candidates(before context: String) -> [Candidate] {
        let words = Self.sentenceWords(in: context)
        if let first = words.first, Self.whWords.contains(first) {
            return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
        }
        return [Candidate(text: "."), Candidate(text: "?"), Candidate(text: "!")]
    }

    /// Words of the sentence being typed, lowercased.
    private static func sentenceWords(in context: String) -> [Substring] {
        context.lowercased()[...].split(whereSeparator: { $0.isWhitespace })
    }
}
