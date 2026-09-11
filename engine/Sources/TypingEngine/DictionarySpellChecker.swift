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
        guard WordRank.index(ofLower: typed) == nil else { return [] }

        // A short word admits one edit; two edits on four letters reaches
        // most of the vocabulary and every candidate is noise.
        let limit = typed.count <= 4 ? 1 : 2
        var scored: [(text: String, distance: Double, rank: Int)] = []
        let typedLetters = WordRank.letterMask(typed)
        // The list is read in place as UTF-8. A byte is a character for the
        // ASCII words, which is all but 341 of them; a pair with a non-ASCII
        // side is decoded so an accent still counts as one edit.
        let typedBytes = Array(typed.utf8)
        let typedScalars = Array(typed.unicodeScalars)
        let typedASCII = typedBytes.count == typedScalars.count
        for length in max(1, typed.count - limit)...(typed.count + limit) {
            let run = WordRank.indices(ofLength: length)
            for k in 0..<(run.count / 4) {
                let i = run.u32(k)
                // Each edit changes at most two letters of the set, so a pair
                // whose letter sets differ by more than 2 * limit cannot be
                // within limit edits. The xor rejects most of the list.
                guard (typedLetters ^ WordRank.mask(at: i)).nonzeroBitCount <= 2 * limit
                else { continue }
                let distance = typedASCII && WordRank.isASCII(at: i)
                    ? EditDistance.damerau(typedBytes, WordRank.lowerBytes(at: i), limit: limit)
                    : EditDistance.damerau(typedScalars, Array(WordRank.lower(at: i).unicodeScalars),
                                           limit: limit)
                guard distance <= limit else { continue }
                scored.append((WordRank.cased(at: i), Double(distance), WordRank.rank(at: i)))
            }
        }
        // Every split rides along after the capped word list. Whether a split
        // is taken, and what it costs against a one-edit word, is
        // `CorrectionEngine`'s call, and a split it would take must not be cut
        // here because eight words sat one edit away.
        return scored
            .sorted {
                $0.distance != $1.distance ? $0.distance < $1.distance
                                           : $0.rank < $1.rank
            }
            .prefix(Self.candidateLimit)
            .map(\.text)
            + splits(of: typed)
    }

    /// A run-together token read as two words, every cut where both halves
    /// are in the list. Stock splits "onmy" into "on my" and "thankyou" into
    /// "thank you", which `UITextChecker` could not propose at all. Which
    /// splits are worth taking is `CorrectionEngine`'s call.
    private func splits(of typed: String) -> [String] {
        let letters = Array(typed)
        var found: [String] = []
        for cut in 1..<letters.count {
            let left = String(letters[..<cut]), right = String(letters[cut...])
            guard let leftIndex = WordRank.index(ofLower: left),
                  let rightIndex = WordRank.index(ofLower: right) else { continue }
            found.append("\(WordRank.cased(at: leftIndex)) \(WordRank.cased(at: rightIndex))")
        }
        return found
    }

    /// Words the list holds that start with the prefix, most frequent first.
    /// The typed prefix itself is not a completion of itself.
    public func completions(for prefix: String) -> [String] {
        let typed = prefix.lowercased()
        guard typed.count >= 2 else { return [] }
        let itself = WordRank.index(ofLower: typed)
        return WordRank.prefixRange(typed)
            .map(WordRank.alphaIndex)
            .filter { $0 != itself }
            .sorted { WordRank.rank(at: $0) < WordRank.rank(at: $1) }
            .prefix(Self.candidateLimit)
            .map(WordRank.cased(at:))
    }
}

/// Damerau-Levenshtein distance, where a transposition counts as one edit.
/// Shared by the candidate scan and `CorrectionEngine`'s distance guard so the
/// two never disagree about how far apart two words are.
enum EditDistance {
    static func damerau(_ a: String, _ b: String, limit: Int = .max) -> Int {
        damerau(Array(a.unicodeScalars), Array(b.unicodeScalars), limit: limit)
    }

    /// - Parameter limit: rows stop early once every cell exceeds it, so a
    ///   far-apart pair costs a fraction of the full matrix.
    static func damerau<S: RandomAccessCollection, T: RandomAccessCollection>(
        _ s: S, _ t: T, limit: Int = .max
    ) -> Int where S.Element == T.Element, S.Element: Equatable, S.Index == Int, T.Index == Int {
        if s.isEmpty { return t.count }
        if t.isEmpty { return s.count }
        let s0 = s.startIndex, t0 = t.startIndex
        var prev2 = [Int](repeating: 0, count: t.count + 1)
        var prev = Array(0...t.count)
        var curr = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            curr[0] = i
            var best = curr[0]
            for j in 1...t.count {
                let cost = s[s0 + i - 1] == t[t0 + j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
                if i > 1, j > 1, s[s0 + i - 1] == t[t0 + j - 2], s[s0 + i - 2] == t[t0 + j - 1] {
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
