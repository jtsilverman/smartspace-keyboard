import Foundation
import PunctuationEngine

/// Extension-sandbox persistence for the text-free outcome log (survives
/// keyboard sessions; not shared with the host app until 4.2/4.3 need it).
struct DefaultsOutcomeStore: OutcomeLogStore {
    private static let key = "outcome-log"

    func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func save(_ lines: [String]) {
        UserDefaults.standard.set(lines, forKey: Self.key)
    }
}
