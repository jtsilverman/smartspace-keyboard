/// The engine's word list, read from `Resources/wordrank.bin` (the Android
/// Open Source Project's LatinIME English dictionary, ordered by its own
/// frequency, then the shipped TextingLexicon; Apache-2.0, provenance and
/// limits in engine/tools/vendor/NOTICE; layout in engine/tools/gen-wordrank.py).
///
/// Position is English word frequency, and membership is "this is a word",
/// which are one fact held in one place: `CorrectionEngine` breaks candidate
/// ties by rank and `DictionarySpellChecker` draws candidates from the same
/// list.
///
/// Lookups are case-insensitive. Each entry keeps the casing the dictionary
/// gives it, so a candidate comes back as `iPhone` rather than `iphone`. The
/// file is memory-mapped and read in place: a record is an index, and every
/// accessor below reads that record's bytes without building a String unless
/// the caller asked for one.
public enum WordRank {
    private static let file = MappedFile.resource("wordrank", magic: "SSWR", version: 2)

    // Header fields, by offset; see gen-wordrank.py.
    private static let count = file.u32(at: 8)
    private static let maxLength = file.u32(at: 12)
    private static let recordsOffset = file.u32(at: 16)
    private static let alphaOffset = file.u32(at: 20)
    private static let lengthStartsOffset = file.u32(at: 24)
    private static let lengthListOffset = file.u32(at: 28)
    private static let stringsOffset = file.u32(at: 32)
    private static let recordSize = 19

    private static func record(_ i: Int) -> Int { recordsOffset + recordSize * i }

    /// The lowercase form's bytes, UTF-8.
    static func lowerBytes(at i: Int) -> UnsafeBufferPointer<UInt8> {
        let r = record(i)
        return file.bytes(at: stringsOffset + file.u32(at: r), count: file.u8(at: r + 16))
    }

    static func lower(at i: Int) -> String {
        String(decoding: lowerBytes(at: i), as: UTF8.self)
    }

    /// The dictionary's own casing for the word.
    static func cased(at i: Int) -> String {
        let r = record(i)
        return String(decoding: file.bytes(at: stringsOffset + file.u32(at: r + 4),
                                           count: file.u8(at: r + 17)), as: UTF8.self)
    }

    /// Position in the full frequency-ordered list, duplicates included.
    static func rank(at i: Int) -> Int { file.u32(at: record(i) + 8) }

    /// Bit per a-z of the lowercase form.
    static func mask(at i: Int) -> UInt32 { UInt32(file.u32(at: record(i) + 12)) }

    /// True when the lowercase form is plain ASCII, so its bytes are its
    /// characters.
    static func isASCII(at i: Int) -> Bool { file.u8(at: record(i) + 18) & 1 == 0 }

    /// Every word with this many characters, in rank order, as a run of
    /// (record index, letter mask) pairs: `run.u32(2 * k)` is the index and
    /// `run.u32(2 * k + 1)` the mask, for `k` in `0..<run.count / 8`. The mask
    /// rides beside the index so a scan rejects most of the run without
    /// touching a record.
    static func lengthRun(_ length: Int) -> UnsafeRawBufferPointer {
        guard length >= 0, length <= maxLength else { return file.u32s(at: lengthListOffset, count: 0) }
        let start = file.u32(at: lengthStartsOffset + 4 * length)
        let end = file.u32(at: lengthStartsOffset + 4 * (length + 1))
        return file.u32s(at: lengthListOffset + 8 * start, count: 2 * (end - start))
    }

    /// The record at position `k` of the alphabetical order.
    static func alphaIndex(_ k: Int) -> Int { file.u32(at: alphaOffset + 4 * k) }

    /// memcmp order of a record's lowercase bytes against `needle`: negative,
    /// zero or positive.
    private static func compare(_ i: Int, _ needle: [UInt8]) -> Int {
        let bytes = lowerBytes(at: i)
        let n = min(bytes.count, needle.count)
        for k in 0..<n where bytes[k] != needle[k] {
            return Int(bytes[k]) - Int(needle[k])
        }
        return bytes.count - needle.count
    }

    /// First alphabetical position whose record does not satisfy `before`,
    /// given that `before` holds for a prefix of the order and then fails.
    private static func partition(_ before: (Int) -> Bool) -> Int {
        MappedFile.partition(count: count) { before(alphaIndex($0)) }
    }

    /// The record of a lowercase word, or nil when the list does not hold it.
    static func index(ofLower lower: String) -> Int? {
        let needle = Array(lower.utf8)
        let k = partition { compare($0, needle) < 0 }
        guard k < count, compare(alphaIndex(k), needle) == 0 else { return nil }
        return alphaIndex(k)
    }

    /// Alphabetical positions of every record whose lowercase form starts
    /// with `prefix`. Map each through `alphaIndex` to reach the record.
    static func prefixRange(_ prefix: String) -> Range<Int> {
        let needle = Array(prefix.utf8)
        let start = partition { compare($0, needle) < 0 }
        // A record sits before the end of the run when it sorts before the
        // prefix or carries it: both compare equal on the shared bytes.
        let end = partition { i in
            let bytes = lowerBytes(at: i)
            for k in 0..<min(bytes.count, needle.count) where bytes[k] != needle[k] {
                return bytes[k] < needle[k]
            }
            return true
        }
        return start..<max(start, end)
    }

    static func letterMask(_ word: String) -> UInt32 {
        var mask: UInt32 = 0
        for scalar in word.unicodeScalars where scalar.value >= 97 && scalar.value <= 122 {
            mask |= 1 << (scalar.value - 97)
        }
        return mask
    }

    /// Rank of a word, case-insensitive; unknown words sink to Int.max.
    public static func rank(_ word: String) -> Int {
        index(ofLower: word.lowercased()).map(rank(at:)) ?? Int.max
    }

    /// True when the dictionary's own casing for the word starts with a
    /// capital, which is how the list marks a proper noun.
    public static func isProperNoun(_ word: String) -> Bool {
        index(ofLower: word.lowercased()).map { cased(at: $0).first?.isUppercase == true } ?? false
    }

    /// True when the list holds the word, case-insensitively. An unknown word
    /// is the one a correction is offered for.
    public static func isKnown(_ word: String) -> Bool {
        index(ofLower: word.lowercased()) != nil
    }
}
