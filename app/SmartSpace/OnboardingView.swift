import SwiftUI

/// WORKPLAN 4.1 skeleton: guided enable + the aha-moment practice field.
/// Enable-detection and screenshots come later; flow and copy are UX-tuned
/// with Jake before any polish.
struct OnboardingView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Turn on SmartSpace")
                .font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 12) {
                step(1, "Open Settings > General > Keyboard > Keyboards")
                step(2, "Tap Add New Keyboard, choose SmartSpace")
                step(3, "SmartSpace never asks for Full Access")
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
            Text("Then come back and try it: type a question in the practice field and double-tap space.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Done") { isPresented = false }
        }
        .padding()
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).").bold().monospacedDigit()
            Text(text)
        }
    }
}
