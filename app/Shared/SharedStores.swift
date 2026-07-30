import Foundation
import PunctuationEngine
import TypingEngine

/// App-group-backed stores shared by the host app (settings writer, stats
/// reader) and the keyboard (settings reader, outcome writer). The pure
/// models live in the engine packages; these adapters are the only place
/// that names UserDefaults.

/// Settings live in the app group: the app writes, the keyboard reads on
/// every appearance (spec host-app-settings AC 4).
struct AppGroupSettingsStore: SettingsStore {
    private let defaults = UserDefaults(suiteName: appGroupID)

    func bool(forKey key: String) -> Bool? {
        defaults?.object(forKey: key) as? Bool
    }

    func string(forKey key: String) -> String? {
        defaults?.string(forKey: key)
    }
}

/// The app side of the same keys. Writing nil removes the override, so the
/// keyboard falls back to the model's defaults.
struct SettingsWriter {
    private let defaults = UserDefaults(suiteName: appGroupID)

    func set(_ value: Bool, forKey key: String) {
        defaults?.set(value, forKey: key)
    }

    func setCandidates(_ marks: Set<Character>) {
        defaults?.set(String(marks.sorted()), forKey: KeyboardSettings.Key.candidates)
    }
}

/// Outcome log in the app group so the stats screen can read what the
/// keyboard writes (WORKPLAN 4.3). Migrates the pre-4.2 log out of the
/// extension's standard defaults on first load.
struct AppGroupOutcomeStore: OutcomeLogStore {
    static let key = "outcome-log"
    private let defaults = UserDefaults(suiteName: appGroupID)

    func load() -> [String] {
        if let lines = defaults?.stringArray(forKey: Self.key) { return lines }
        // One-time migration: the 3.7 log lived in the extension sandbox.
        if let legacy = UserDefaults.standard.stringArray(forKey: Self.key) {
            defaults?.set(legacy, forKey: Self.key)
            UserDefaults.standard.removeObject(forKey: Self.key)
            return legacy
        }
        return []
    }

    func save(_ lines: [String]) {
        defaults?.set(lines, forKey: Self.key)
    }
}
