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

    /// Auxiliary/modal verbs that start yes-no questions when a pronoun follows
    /// ("do you...", "can we..."); without one they usually open a command
    /// ("do your homework").
    private static let auxiliaries: Set<Substring> = [
        "do", "does", "did", "am", "are", "is", "was", "were",
        "can", "could", "will", "would", "should", "shall", "may", "might",
        "have", "has", "had"
    ]

    private static let pronouns: Set<Substring> = [
        "i", "you", "we", "they", "he", "she", "it", "u", "ya", "anyone", "anybody"
    ]

    public init() {}

    /// Returns candidates ranked best-first for the text before the cursor.
    public func candidates(before context: String) -> [Candidate] {
        let words = Self.sentenceWords(in: context)
        if let first = words.first {
            if Self.whWords.contains(first) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if Self.auxiliaries.contains(first), words.count > 1,
               Self.pronouns.contains(words[1]) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
        }
        return [Candidate(text: "."), Candidate(text: "?"), Candidate(text: "!")]
    }

    /// Words of the sentence being typed (text after the last terminal mark), lowercased.
    private static func sentenceWords(in context: String) -> [Substring] {
        let current = context.split(omittingEmptySubsequences: false,
                                    whereSeparator: { ".!?".contains($0) }).last ?? ""
        return current.lowercased()[...].split(whereSeparator: { $0.isWhitespace })
    }
}
