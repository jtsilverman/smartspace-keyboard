/// Pure settings model shared by the host app (writer) and keyboard (reader).
/// Both sides talk to the app-group UserDefaults through this seam; tests
/// inject an in-memory store, matching EmojiRecents/OutcomeLog.

public protocol SettingsStore {
    func bool(forKey key: String) -> Bool?
    func string(forKey key: String) -> String?
}

/// Feature toggles + the double-space candidate set, decoded per-key with
/// defaults so a corrupt or missing value never disables the keyboard.
public struct KeyboardSettings {
    public enum Key {
        public static let smartDoubleSpace = "settings.smartDoubleSpace"
        public static let autocorrect = "settings.autocorrect"
        public static let autoCapitalization = "settings.autoCapitalization"
        public static let smartSymbols = "settings.smartSymbols"
        public static let haptics = "settings.haptics"
        public static let candidates = "settings.candidates"
    }

    /// Marks the settings screen may offer, and the only ones a stored
    /// candidate string can enable.
    public static let availableCandidates: Set<Character> = [".", "?", "!", ",", "\"", ":", ";", "-"]
    public static let defaultCandidates: Set<Character> = [".", "?", "!", ",", "\""]

    public let smartDoubleSpace: Bool
    public let autocorrect: Bool
    public let autoCapitalization: Bool
    public let smartSymbols: Bool
    public let haptics: Bool
    public let enabledCandidates: Set<Character>

    public init(store: SettingsStore) {
        smartDoubleSpace = store.bool(forKey: Key.smartDoubleSpace) ?? true
        autocorrect = store.bool(forKey: Key.autocorrect) ?? true
        autoCapitalization = store.bool(forKey: Key.autoCapitalization) ?? true
        smartSymbols = store.bool(forKey: Key.smartSymbols) ?? true
        haptics = store.bool(forKey: Key.haptics) ?? true
        let stored = Set((store.string(forKey: Key.candidates) ?? "")
            .filter { Self.availableCandidates.contains($0) })
        enabledCandidates = stored.isEmpty ? Self.defaultCandidates : stored
    }

    /// Removes disabled marks from an engine candidate list without
    /// reordering it (order stays engine confidence).
    public func filterCandidates(_ marks: [Character]) -> [Character] {
        marks.filter { enabledCandidates.contains($0) }
    }
}
