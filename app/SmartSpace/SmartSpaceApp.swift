import SwiftUI
import TypingEngine

@main
struct SmartSpaceApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Practice / Settings / Stats. Onboarding opens from the practice screen;
/// auto-present-on-first-launch is deferred until enable-detection exists
/// (a fresh-install sheet would also sit in front of every XCUITest).
struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { PracticeView() }
                .tabItem { Label("Practice", systemImage: "keyboard") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "switch.2") }
            NavigationStack { StatsView() }
                .tabItem { Label("Stats", systemImage: "chart.bar") }
        }
        .onAppear(perform: applyUITestSettingsOverride)
    }

    /// XCUITest hook: SwiftUI Form toggle taps do not register on the iOS
    /// 26.5 simulator, and file-level plist seeding is invisible through
    /// cfprefsd -- so toggle tests drive the real SettingsWriter path via
    /// launch arguments instead.
    private func applyUITestSettingsOverride() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        let featureKeys = [KeyboardSettings.Key.smartDoubleSpace,
                           KeyboardSettings.Key.autocorrect,
                           KeyboardSettings.Key.autoCapitalization,
                           KeyboardSettings.Key.smartSymbols,
                           KeyboardSettings.Key.haptics]
        let writer = SettingsWriter()
        if args.contains("-uitest-smart-features-off") {
            featureKeys.forEach { writer.set(false, forKey: $0) }
        }
        if args.contains("-uitest-smart-features-on") {
            featureKeys.forEach { writer.set(true, forKey: $0) }
        }
        #endif
    }
}

/// The pre-4.x practice field, unchanged behavior: XCUITests type here.
struct PracticeView: View {
    @State private var text = ""
    @State private var showOnboarding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("SmartSpace")
                .font(.largeTitle.bold())
            Text("Enable the keyboard in Settings > General > Keyboard > Keyboards, then type below.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Type here to test the keyboard", text: $text)
                .textFieldStyle(.roundedBorder)
            Button("Setup guide") { showOnboarding = true }
                .font(.callout)
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onAppear {
            // The 3.1 app-group probe: the keyboard reads this back without
            // Full Access and shows AG:OK or AG:BLOCKED.
            UserDefaults(suiteName: appGroupID)?.set(probeValue, forKey: probeKey)
        }
    }
}
