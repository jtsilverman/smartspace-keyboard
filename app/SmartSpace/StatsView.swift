import SwiftUI
import PunctuationEngine

/// WORKPLAN 4.3: on-device stats from the text-free outcome log the
/// keyboard writes to the app group. All-time window for now (records
/// carry no timestamps; weekly windows are an open spec question).
struct StatsView: View {
    @State private var stats = OutcomeStats([])

    var body: some View {
        List {
            Section("Smart punctuation") {
                LabeledContent("Smart punctuations", value: "\(stats.total)")
                LabeledContent("Kept without cycling", value: keptPercent)
            }
            if !stats.keptByMark.isEmpty {
                Section("By mark") {
                    ForEach(stats.keptByMark.sorted { $0.value > $1.value }, id: \.key) { mark, count in
                        LabeledContent(mark, value: "\(count)")
                    }
                }
            }
            Section {
                Text("Computed on this device from counts only. No typed text is ever stored.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Stats")
        .onAppear {
            stats = OutcomeLog(store: AppGroupOutcomeStore()).stats
        }
    }

    private var keptPercent: String {
        guard stats.total > 0 else { return "—" }
        return "\(stats.keptWithoutCycling * 100 / stats.total)%"
    }
}
