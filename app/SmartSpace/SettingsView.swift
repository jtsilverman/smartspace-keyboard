import SwiftUI
import TypingEngine

/// WORKPLAN 4.2: feature toggles + the double-space candidate set, written
/// to the app-group defaults the keyboard reads on its next appearance.
/// Deliberately stock SwiftUI -- visual design is tuned with Jake later.
struct SettingsView: View {
    private let writer = SettingsWriter()

    @AppStorage(KeyboardSettings.Key.smartDoubleSpace, store: UserDefaults(suiteName: appGroupID))
    private var smartDoubleSpace = true
    @AppStorage(KeyboardSettings.Key.autocorrect, store: UserDefaults(suiteName: appGroupID))
    private var autocorrect = true
    @AppStorage(KeyboardSettings.Key.autoCapitalization, store: UserDefaults(suiteName: appGroupID))
    private var autoCapitalization = true
    @AppStorage(KeyboardSettings.Key.smartSymbols, store: UserDefaults(suiteName: appGroupID))
    private var smartSymbols = true
    @AppStorage(KeyboardSettings.Key.haptics, store: UserDefaults(suiteName: appGroupID))
    private var haptics = true
    @AppStorage(KeyboardSettings.Key.candidates, store: UserDefaults(suiteName: appGroupID))
    private var candidates = ".?!"

    /// Display order: defaults first, optional marks after.
    private let candidateOrder: [Character] = [".", "?", "!", ",", ":", ";", "-"]

    var body: some View {
        Form {
            Section("Smart features") {
                Toggle("Smart double-space", isOn: $smartDoubleSpace)
                    .accessibilityIdentifier("toggle-smart-double-space")
                Toggle("Autocorrect", isOn: $autocorrect)
                    .accessibilityIdentifier("toggle-autocorrect")
                Toggle("Auto-capitalization", isOn: $autoCapitalization)
                    .accessibilityIdentifier("toggle-auto-capitalization")
                Toggle("Smart quotes & dashes", isOn: $smartSymbols)
                    .accessibilityIdentifier("toggle-smart-symbols")
                Toggle("Haptics", isOn: $haptics)
                    .accessibilityIdentifier("toggle-haptics")
            }
            Section {
                ForEach(candidateOrder, id: \.self) { mark in
                    Toggle(String(mark), isOn: binding(for: mark))
                        .accessibilityIdentifier("candidate-\(mark)")
                }
            } header: {
                Text("Double-space punctuation")
            } footer: {
                Text("Marks the double-space guess may choose from. Order follows the engine's confidence, not this list.")
            }
        }
        .navigationTitle("Settings")
    }

    private func binding(for mark: Character) -> Binding<Bool> {
        Binding(
            get: { candidates.contains(mark) },
            set: { enabled in
                var set = Set(candidates)
                if enabled { set.insert(mark) } else { set.remove(mark) }
                // Never allow an empty set: the keyboard would degrade to
                // defaults anyway, so keep the stored value honest.
                if set.isEmpty { set = KeyboardSettings.defaultCandidates }
                candidates = String(candidateOrder.filter(set.contains))
            }
        )
    }
}
