/// Adapts candidate order to the user's own habits: marks they actually
/// keep under a rule rise in that rule's cycle order. Pure counters, no
/// text. A rule is left at its engine order until it has enough outcomes
/// that one stray keep cannot flip it.
public struct PersonalRanking: Equatable, Sendable {
    /// Outcomes required for a rule before its order is nudged.
    public static let minimumOutcomes = 5

    private var keptCounts: [PredictionRule: [String: Int]] = [:]

    public init() {
    }

    /// Feeds one self-labeled outcome into the counters.
    public mutating func record(_ outcome: OutcomeRecord) {
        keptCounts[outcome.rule, default: [:]][outcome.kept, default: 0] += 1
    }

    /// The prediction's candidates, reordered by this user's kept counts
    /// for the rule that fired; engine order breaks ties and rules the
    /// counters have not earned an opinion on.
    public func reranked(_ prediction: Prediction) -> [Candidate] {
        let counts = keptCounts[prediction.rule, default: [:]]
        guard counts.values.reduce(0, +) >= Self.minimumOutcomes else {
            return prediction.candidates
        }
        return prediction.candidates.enumerated()
            .sorted { (counts[$0.element.text, default: 0], $1.offset) >
                      (counts[$1.element.text, default: 0], $0.offset) }
            .map(\.element)
    }
}
