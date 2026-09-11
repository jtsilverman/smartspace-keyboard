/// The engine's word-pair table, read from `Resources/wordpairs.bin`: how
/// often one word follows another in web text (Norvig's bigram counts, kept
/// where both words are in `WordRank` and the count reaches 300,000;
/// provenance and limits in engine/tools/vendor/NOTICE, layout in
/// engine/tools/gen-wordpairs.py). `WordPairModel` reads it to rank
/// correction candidates by the word before them.
///
/// Memory-mapped and searched in place: a pair is two `WordRank` record
/// indices, and the file is sorted by them.
enum WordPairs {
    private static let file = MappedFile.resource("wordpairs", magic: "SSWP", version: 2)
    private static let count = file.u32(at: 8)
    private static let recordsOffset = 12
    private static let recordSize = 12

    /// The count for the pair, or nil when the table has never seen it.
    static func count(first: Int, second: Int) -> Int? {
        let k = MappedFile.partition(count: count) { mid in
            let r = recordsOffset + recordSize * mid
            let a = file.u32(at: r), b = file.u32(at: r + 4)
            return a < first || (a == first && b < second)
        }
        guard k < count else { return nil }
        let r = recordsOffset + recordSize * k
        guard file.u32(at: r) == first, file.u32(at: r + 4) == second else { return nil }
        return file.u32(at: r + 8)
    }
}
