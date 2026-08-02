import SwiftUI
import PunctuationEngine

/// WORKPLAN 4.3: on-device stats from the text-free outcome log the
/// keyboard writes to the app group. All-time plus a rolling 7-day window
/// (records stamped with an epoch day; pre-stamp records count only in
/// all-time).
struct StatsView: View {
    @State private var stats = OutcomeStats([])
    @State private var weekStats = OutcomeStats([])

    var body: some View {
        List {
            Section("This week") {
                LabeledContent("Smart punctuations", value: "\(weekStats.total)")
                LabeledContent("Kept without cycling",
                               value: Self.keptPercent(weekStats))
            }
            Section("All time") {
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
            let records = OutcomeLog(store: AppGroupOutcomeStore()).records
            stats = OutcomeStats(records)
            let weekStart = Int(Date().timeIntervalSince1970 / 86400) - 6
            weekStats = OutcomeStats(records.filter {
                ($0.epochDay ?? .min) >= weekStart
            })
        }
    }

    private var keptPercent: String { Self.keptPercent(stats) }

    private static func keptPercent(_ stats: OutcomeStats) -> String {
        guard stats.total > 0 else { return "—" }
        return "\(stats.keptWithoutCycling * 100 / stats.total)%"
    }
}
