import Foundation
import TypingEngine

/// Extension-sandbox persistence for emoji recents (survives keyboard
/// sessions; not shared with the host app).
struct DefaultsRecentsStore: EmojiRecentsStore {
    private static let key = "emoji-recents"

    func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func save(_ recents: [String]) {
        UserDefaults.standard.set(recents, forKey: Self.key)
    }
}
