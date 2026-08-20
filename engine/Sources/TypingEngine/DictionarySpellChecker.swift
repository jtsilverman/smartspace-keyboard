/// Our own candidate source, replacing `UITextChecker` (unit 1 of
/// specs/autocorrect-parity.md, vision milestone 5). `UITextChecker` sees one
/// word at a time, returns guesses alphabetically, and cannot propose two
/// words for one token, so missed spaces are impossible however good the
/// re-ranking above it.
///
/// Candidates come from `WordRank`, the engine's own word list, scanned within
/// an edit budget. The scan reads only the length buckets inside that budget,
/// so a lookup never walks the whole list.
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
        let typedLetters = WordRank.letterMask(typed)
        for length in max(1, typed.count - limit)...(typed.count + limit) {
            for entry in WordRank.byLength[length] ?? [] {
                // Each edit changes at most two letters of the set, so a pair
                // whose letter sets differ by more than 2 * limit cannot be
                // within limit edits. The xor rejects most of the list.
                guard (typedLetters ^ entry.letters).nonzeroBitCount <= 2 * limit
                else { continue }
                let distance = EditDistance.damerau(typed, entry.lower, limit: limit)
                guard distance <= limit else { continue }
                scored.append((WordRank.cased[entry.lower] ?? entry.lower, distance,
                               WordRank.ranked[entry.lower] ?? .max))
            }
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
        let bucket = WordRank.byPrefix[String(typed.prefix(2))] ?? []
        return bucket
            .filter { $0.hasPrefix(typed) && $0 != typed }
            .sorted { (WordRank.ranked[$0] ?? .max) < (WordRank.ranked[$1] ?? .max) }
            .prefix(Self.candidateLimit)
            .map { WordRank.cased[$0] ?? $0 }
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
