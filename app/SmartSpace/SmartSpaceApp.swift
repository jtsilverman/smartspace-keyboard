import SwiftUI

let appGroupID = "group.com.jtsilverman.smartspace"
let probeKey = "appGroupProbe"
let probeValue = "probe-v1"

@main
struct SmartSpaceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("SmartSpace")
                .font(.largeTitle.bold())
            Text("Enable the keyboard in Settings > General > Keyboard > Keyboards, then type below.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Type here to test the keyboard", text: $text)
                .textFieldStyle(.roundedBorder)
            Spacer()
        }
        .padding()
        .onAppear {
            // The 3.1 app-group probe: the keyboard reads this back without
            // Full Access and shows AG:OK or AG:BLOCKED.
            UserDefaults(suiteName: appGroupID)?.set(probeValue, forKey: probeKey)
        }
    }
}
