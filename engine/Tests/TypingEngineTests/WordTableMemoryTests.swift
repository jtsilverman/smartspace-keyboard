import Testing
import Darwin
@testable import TypingEngine

/// Check 6 of specs/autocorrect-parity.md, vision milestone 1: the keyboard
/// extension's resident memory must stay under 55MB, and iOS kills a keyboard
/// that grows past its ceiling. The word list and the word-pair table are the
/// engine's two large tables; unit 1 named them memory-mapped, and the
/// extension measured a 70MB footprint on 2026-09-11 with both heap-resident.
@Suite struct WordTableMemoryTests {
    /// Heap in use after both tables are loaded, in bytes, as malloc reports
    /// it for the whole test process. The budget leaves the tables no room to
    /// be heap copies: 165,804 words in four dictionaries and 90,310 pairs in
    /// one measured about 50MB.
    @Test func loadedWordTablesLeaveTheHeapSmall() {
        #expect(WordRank.isKnown("the"))
        #expect(WordPairModel().likelihood(of: "the", after: ["of"]) != nil)
        var stats = malloc_statistics_t()
        malloc_zone_statistics(nil, &stats)
        let inUse = Int(stats.size_in_use)
        print("HEAP-IN-USE after word tables: \(inUse / 1_048_576)MB")
        #expect(inUse < 16 * 1_048_576, "heap in use \(inUse / 1_048_576)MB")
    }
}
