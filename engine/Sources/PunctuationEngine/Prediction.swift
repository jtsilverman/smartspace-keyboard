/// The rule path that produced a prediction. String-backed so outcome
/// records stay readable when persisted.
public enum PredictionRule: String, Sendable, CaseIterable {
    case dottedAbbreviation
    case abbreviation
    case terminalGuard
    case question
    case comma
    case list
    case quote
    case exclamation
    case fallback
}

/// Ranked candidates plus the rule that produced them.
public struct Prediction: Equatable, Sendable {
    public let rule: PredictionRule
    public let candidates: [Candidate]

    public init(rule: PredictionRule, candidates: [Candidate]) {
        self.rule = rule
        self.candidates = candidates
    }
}
