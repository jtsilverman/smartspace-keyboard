/// Pure logic behind the emoji panel: MRU recents behind a storage seam and
/// ranked search over the curated catalog. The keyboard renders grids and
/// persists recents via UserDefaults; tests inject an in-memory store.

public protocol EmojiRecentsStore {
    func load() -> [String]
    func save(_ recents: [String])
}

/// Most-recently-used emoji, capped, deduplicated, persisted on every write.
public struct EmojiRecents {
    public static let cap = 30

    private let store: EmojiRecentsStore
    private var list: [String]

    public init(store: EmojiRecentsStore) {
        self.store = store
        list = Array(store.load().prefix(Self.cap))
    }

    public var all: [String] { list }

    public mutating func record(_ emoji: String) {
        list.removeAll { $0 == emoji }
        list.insert(emoji, at: 0)
        if list.count > Self.cap { list = Array(list.prefix(Self.cap)) }
        store.save(list)
    }
}

/// Case-insensitive search: entries whose full name starts with the query
/// rank first, then any name/keyword token-prefix match; catalog order
/// within each rank; capped at 24 for the one-row result strip.
public enum EmojiSearch {
    public static let resultCap = 24

    public static func results(for query: String) -> [String] {
        let q = query.lowercased().split(separator: " ").joined(separator: " ")
        guard !q.isEmpty else { return [] }
        var nameHits: [String] = []
        var tokenHits: [String] = []
        for entry in EmojiCatalog.entries {
            if entry.name.hasPrefix(q) {
                nameHits.append(entry.emoji)
            } else if entry.name.split(separator: " ").contains(where: { $0.hasPrefix(q) })
                        || entry.keywords.split(separator: " ").contains(where: { $0.hasPrefix(q) }) {
                tokenHits.append(entry.emoji)
            }
        }
        return Array((nameHits + tokenHits).prefix(resultCap))
    }
}
