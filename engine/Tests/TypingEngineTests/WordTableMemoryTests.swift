import Testing
import Darwin
@testable import TypingEngine

/// Check 6 of specs/autocorrect-parity.md, vision milestone 1: the keyboard
/// extension's resident memory must stay under 55MB, and iOS kills a keyboard
/// that grows past its ceiling. The word list and the word-pair table are the
/// engine's two large tables; unit 1 named them memory-mapped, and the
/// extension measured a 70MB footprint on 2026-09-11 with both heap-resident.
@Suite struct WordTableMemoryTests {
    /// Heap malloc reports as in use, for the whole test process.
    private func heapInUse() -> Int {
        var stats = malloc_statistics_t()
        malloc_zone_statistics(nil, &stats)
        return Int(stats.size_in_use)
    }

    /// Loading both tables must not grow the heap: the budget leaves them no
    /// room to be heap copies. 165,804 words in four dictionaries and 90,310
    /// pairs in one measured 23MB here and about 50MB in the extension.
    ///
    /// Run alone, this is the proof. In a full run another suite may have
    /// loaded the tables first, which zeroes the delta, and the process heap
    /// carries 19MB of corpora either way, so no absolute bound separates the
    /// two. The gate that holds in every order is the extension footprint
    /// recorded in EVAL.md.
    @Test func loadedWordTablesLeaveTheHeapSmall() {
        let before = heapInUse()
        #expect(WordRank.isKnown("the"))
        #expect(WordPairModel().likelihood(of: "the", after: ["of"]) != nil)
        let grown = heapInUse() - before
        print("HEAP grown by loading word tables: \(grown / 1024)KB")
        #expect(grown < 4 * 1_048_576, "heap grew \(grown / 1024)KB")
    }
}
