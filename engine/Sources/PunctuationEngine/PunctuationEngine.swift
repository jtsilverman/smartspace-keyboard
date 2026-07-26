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

    /// Auxiliary/modal verbs that open a yes-no question whenever they start a
    /// sentence ("was your day good", "can your brother come").
    private static let auxiliaries: Set<Substring> = [
        "does", "did", "am", "are", "is", "was", "were",
        "can", "could", "will", "would", "should", "shall", "may", "might",
        "has", "had"
    ]

    /// Auxiliaries that also head commands/statements ("do your homework",
    /// "have a great day"), so they only signal a question when a pronoun
    /// follows ("do you...", "have you...").
    private static let imperativeCapableAuxiliaries: Set<Substring> = ["do", "have"]

    /// Bare-verb sentence openers that read as invitations in texting
    /// ("want to grab dinner", "wanna come").
    private static let requestVerbs: Set<Substring> = ["want", "wanna"]

    private static let pronouns: Set<Substring> = [
        "i", "you", "we", "they", "he", "she", "it", "u", "ya", "anyone", "anybody"
    ]

    /// Sentence-final words that turn a statement into a tag question
    /// ("you're coming tonight right").
    private static let trailingTags: Set<Substring> = [
        "right", "ok", "okay", "huh", "eh", "yeah"
    ]

    public init() {}

    /// Returns candidates ranked best-first for the text before the cursor.
    public func candidates(before context: String) -> [Candidate] {
        let words = Self.sentenceWords(in: context)
        if let first = words.first {
            if Self.whWords.contains(first) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if Self.auxiliaries.contains(first) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if Self.imperativeCapableAuxiliaries.contains(first), words.count > 1,
               Self.pronouns.contains(words[1]) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if Self.requestVerbs.contains(first) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if let last = words.last, words.count > 1, Self.trailingTags.contains(last) {
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
