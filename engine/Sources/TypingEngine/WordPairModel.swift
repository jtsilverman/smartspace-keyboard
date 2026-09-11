/// The sentence-context seam (unit 4 of specs/autocorrect-parity.md, vision
/// milestone 5). `CorrectionEngine` asks it how well each candidate follows
/// the words already typed, and breaks a distance tie on the answer. Unit 4a
/// answers from a word-pair table; unit 4b replaces the answer with a trained
/// model behind this same seam.
public protocol ContextScoring: Sendable {
    /// How likely `word` is to follow `previous`, most recent word last.
    /// Higher is likelier, and the scale is only comparable between
    /// candidates scored against the same `previous`. Zero means the model
    /// has no opinion, so the caller falls through to its next tiebreak.
    func likelihood(of word: String, after previous: [String]) -> Double
}

/// Reads the word before a candidate off `WordPairs`. It sees one word back:
/// a pair table has no longer memory, which is the limit unit 4b lifts.
public struct WordPairModel: ContextScoring {
    public init() {}

    public func likelihood(of word: String, after previous: [String]) -> Double {
        guard let before = previous.last else { return 0 }
        return Double(WordPairs.counts["\(before.lowercased()) \(word.lowercased())"] ?? 0)
    }
}
