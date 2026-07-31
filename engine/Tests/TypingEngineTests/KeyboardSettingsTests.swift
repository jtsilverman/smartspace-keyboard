import Testing
@testable import TypingEngine

/// In-memory stand-in for the app-group UserDefaults both targets share.
private final class MemorySettingsStore: SettingsStore {
    var bools: [String: Bool] = [:]
    var strings: [String: String] = [:]
    func bool(forKey key: String) -> Bool? { bools[key] }
    func string(forKey key: String) -> String? { strings[key] }
}

// Spec host-app-settings AC 1: empty store yields defaults, overrides
// round-trip, corrupt values degrade per-key.
@Suite struct KeyboardSettingsTests {
    @Test func emptyStoreYieldsAllFeaturesOnAndDefaultCandidates() {
        let settings = KeyboardSettings(store: MemorySettingsStore())
        #expect(settings.smartDoubleSpace)
        #expect(settings.autocorrect)
        #expect(settings.autoCapitalization)
        #expect(settings.smartSymbols)
        #expect(settings.haptics)
        #expect(settings.enabledCandidates == [".", "?", "!", ",", "\""])
    }

    // Jake 2026-07-31: comma and quote join the defaults -- the engine's
    // .comma/.quote rules were silently dead under the ". ? !" default.
    @Test func quoteIsAvailableAndStorableAsACandidate() {
        let store = MemorySettingsStore()
        store.strings[KeyboardSettings.Key.candidates] = ".\""
        let settings = KeyboardSettings(store: store)
        #expect(settings.enabledCandidates == [".", "\""])
        #expect(settings.filterCandidates(["\"", ",", "."]) == ["\"", "."])
    }

    @Test func storedToggleOffIsReadWithoutTouchingOtherKeys() {
        let store = MemorySettingsStore()
        store.bools[KeyboardSettings.Key.smartDoubleSpace] = false
        let settings = KeyboardSettings(store: store)
        #expect(!settings.smartDoubleSpace)
        #expect(settings.autocorrect)
        #expect(settings.haptics)
    }

    @Test func candidateStringEnablesOptionalMarks() {
        let store = MemorySettingsStore()
        store.strings[KeyboardSettings.Key.candidates] = ".?!,"
        let settings = KeyboardSettings(store: store)
        #expect(settings.enabledCandidates == [".", "?", "!", ","])
    }

    @Test func candidateStringWithNoValidMarksDegradesToDefaults() {
        let store = MemorySettingsStore()
        store.strings[KeyboardSettings.Key.candidates] = "xz9"
        let settings = KeyboardSettings(store: store)
        #expect(settings.enabledCandidates == [".", "?", "!", ",", "\""])
    }

    @Test func unknownCharactersInCandidateStringAreDropped() {
        let store = MemorySettingsStore()
        store.strings[KeyboardSettings.Key.candidates] = ".x?"
        let settings = KeyboardSettings(store: store)
        #expect(settings.enabledCandidates == [".", "?"])
    }
}

// Spec host-app-settings AC 2: the candidate filter keeps engine-confidence
// order and only removes disabled marks.
@Suite struct CandidateFilterTests {
    @Test func filterPreservesEngineOrder() {
        let store = MemorySettingsStore()
        store.strings[KeyboardSettings.Key.candidates] = ".!"
        let settings = KeyboardSettings(store: store)
        #expect(settings.filterCandidates(["?", ".", "!"]) == [".", "!"])
    }

    @Test func defaultSetPassesDefaultMarksThroughUnchanged() {
        let settings = KeyboardSettings(store: MemorySettingsStore())
        #expect(settings.filterCandidates(["?", ".", "!"]) == ["?", ".", "!"])
    }

    @Test func optionalMarkSurvivesFilterWhenEnabled() {
        let store = MemorySettingsStore()
        store.strings[KeyboardSettings.Key.candidates] = ".?!,"
        let settings = KeyboardSettings(store: store)
        #expect(settings.filterCandidates([",", "."]) == [",", "."])
    }
}
