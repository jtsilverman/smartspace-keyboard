import Testing
@testable import TypingEngine

/// In-memory stand-in for the extension's UserDefaults-backed store.
private final class MemoryStore: EmojiRecentsStore {
    var stored: [String] = []
    func load() -> [String] { stored }
    func save(_ recents: [String]) { stored = recents }
}

// Spec emoji-panel AC 1: MRU recents behind a storage seam.
@Suite struct EmojiRecentsTests {
    @Test func recordingPutsEmojiAtTheFront() {
        var recents = EmojiRecents(store: MemoryStore())
        recents.record("😀")
        recents.record("🐶")
        #expect(recents.all == ["🐶", "😀"])
    }

    @Test func reRecordingMovesToFrontWithoutDuplicate() {
        var recents = EmojiRecents(store: MemoryStore())
        recents.record("😀")
        recents.record("🐶")
        recents.record("😀")
        #expect(recents.all == ["😀", "🐶"])
    }

    @Test func capsAtThirty() {
        var recents = EmojiRecents(store: MemoryStore())
        let catalog = EmojiCatalog.entries.prefix(35).map(\.emoji)
        for e in catalog { recents.record(e) }
        #expect(recents.all.count == 30)
        #expect(recents.all.first == catalog.last)
    }

    @Test func roundTripsThroughTheStore() {
        let store = MemoryStore()
        var first = EmojiRecents(store: store)
        first.record("🍕")
        let second = EmojiRecents(store: store)
        #expect(second.all == ["🍕"])
    }
}

// Spec emoji-panel AC 2: case-insensitive name/keyword search, name-prefix
// matches ranked first, capped at 24.
@Suite struct EmojiSearchTests {
    @Test func findsByNameCaseInsensitive() {
        #expect(EmojiSearch.results(for: "HEART").contains("❤️"))
    }

    @Test func findsByKeyword() {
        #expect(EmojiSearch.results(for: "dog").contains("🐶"))
    }

    @Test func namePrefixRanksBeforeKeywordMatch() {
        // "cat" is a name prefix for the cat face and (at best) a keyword
        // elsewhere; the name-prefix hit must come first.
        let results = EmojiSearch.results(for: "cat")
        #expect(results.first == "🐱")
    }

    @Test func emptyAndWhitespaceQueriesReturnNothing() {
        #expect(EmojiSearch.results(for: "").isEmpty)
        #expect(EmojiSearch.results(for: "   ").isEmpty)
    }

    @Test func resultsCapAtTwentyFour() {
        // Single letters match broadly; the cap must hold for any query.
        #expect(EmojiSearch.results(for: "s").count <= 24)
    }
}

// Spec emoji-panel AC 3: catalog integrity.
@Suite struct EmojiCatalogTests {
    @Test func everyEntryIsComplete() {
        for entry in EmojiCatalog.entries {
            #expect(!entry.emoji.isEmpty)
            #expect(!entry.name.isEmpty)
        }
    }

    @Test func allEightCategoriesAreNonEmpty() {
        #expect(EmojiCategory.allCases.count == 8)
        for category in EmojiCategory.allCases {
            #expect(EmojiCatalog.entries.contains { $0.category == category },
                    "empty category: \(category)")
        }
    }

    @Test func noDuplicateEmoji() {
        let all = EmojiCatalog.entries.map(\.emoji)
        #expect(Set(all).count == all.count)
    }
}
