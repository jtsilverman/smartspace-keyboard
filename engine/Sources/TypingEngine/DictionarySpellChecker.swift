/// Our own candidate source, replacing `UITextChecker` (unit 1 of
/// specs/autocorrect-parity.md, vision milestone 5). `UITextChecker` sees one
/// word at a time, returns guesses alphabetically, and cannot propose two
/// words for one token, so missed spaces are impossible however good the
/// re-ranking above it.
///
/// The vocabulary is `WordRank`'s 20k frequency-ranked words, which the engine
/// already ships. Candidates come from a scan of that vocabulary bounded by
/// edit distance; a scan is the simplest thing that runs, and the bench in
/// `TypoBenchmarkTests` is what says whether it needs an index.
public struct DictionarySpellChecker: SpellChecking {
    /// Candidates handed up to `CorrectionEngine`, which applies its own
    /// guards and re-ranking. Eight is past the three the bar can show.
    private static let candidateLimit = 8

    public init() {}

    public func suggestions(for word: String) -> [String] {
        let typed = word.lowercased()
        guard !typed.isEmpty else { return [] }
        // The seam's contract: an empty list means the word is spelled
        // correctly.
        guard WordRank.ranked[typed] == nil else { return [] }

        // A short word admits one edit; two edits on four letters reaches
        // most of the vocabulary and every candidate is noise.
        let limit = typed.count <= 4 ? 1 : 2
        var scored: [(text: String, distance: Int, rank: Int)] = []
        for (candidate, rank) in WordRank.ranked {
            // Length alone rules out most of the vocabulary, and it costs one
            // comparison against the distance matrix's O(n*m).
            guard abs(candidate.count - typed.count) <= limit else { continue }
            let distance = EditDistance.damerau(typed, candidate, limit: limit)
            guard distance <= limit else { continue }
            scored.append((candidate, distance, rank))
        }
        return scored
            .sorted {
                $0.distance != $1.distance ? $0.distance < $1.distance
                                           : $0.rank < $1.rank
            }
            .prefix(Self.candidateLimit)
            .map(\.text)
    }

    /// Words the list holds that start with the prefix, most frequent first.
    /// The typed prefix itself is not a completion of itself.
    public func completions(for prefix: String) -> [String] {
        let typed = prefix.lowercased()
        guard typed.count >= 2 else { return [] }
        return WordRank.ranked
            .filter { $0.key.hasPrefix(typed) && $0.key != typed }
            .sorted { $0.value < $1.value }
            .prefix(Self.candidateLimit)
            .map(\.key)
    }
}

/// Damerau-Levenshtein distance, where a transposition counts as one edit.
/// Shared by the candidate scan and `CorrectionEngine`'s distance guard so the
/// two never disagree about how far apart two words are.
enum EditDistance {
    /// - Parameter limit: rows stop early once every cell exceeds it, so a
    ///   far-apart pair costs a fraction of the full matrix.
    static func damerau(_ a: String, _ b: String, limit: Int = .max) -> Int {
        let s = Array(a), t = Array(b)
        if s.isEmpty { return t.count }
        if t.isEmpty { return s.count }
        var prev2 = [Int](repeating: 0, count: t.count + 1)
        var prev = Array(0...t.count)
        var curr = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            curr[0] = i
            var best = curr[0]
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
                if i > 1, j > 1, s[i - 1] == t[j - 2], s[i - 2] == t[j - 1] {
                    curr[j] = min(curr[j], prev2[j - 2] + 1)
                }
                best = min(best, curr[j])
            }
            if best > limit { return best }
            (prev2, prev, curr) = (prev, curr, prev2)
        }
        return prev[t.count]
    }
}
