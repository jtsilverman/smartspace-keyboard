/// Sentence length coarsened to a bucket so records carry no hint of the
/// actual text.
public enum LengthBucket: String, Sendable, Equatable {
    case short
    case medium
    case long

    public init(wordCount: Int) {
        self = .long
    }
}

/// One double-space interaction, self-labeled: what the engine guessed and
/// what the user finally kept. Text-free by construction -- marks, counts,
/// and a bucket; never the sentence.
public struct OutcomeRecord: Equatable, Sendable {
    public let rule: PredictionRule
    public let guess: String
    public let kept: String
    public let cycleTaps: Int
    public let lengthBucket: LengthBucket

    public init(rule: PredictionRule, guess: String, kept: String,
                cycleTaps: Int, lengthBucket: LengthBucket) {
        self.rule = rule
        self.guess = guess
        self.kept = kept
        self.cycleTaps = cycleTaps
        self.lengthBucket = lengthBucket
    }
}

/// The counts the stats screen and personal re-ranking both read.
public struct OutcomeStats: Equatable, Sendable {
    public let total: Int
    public let keptWithoutCycling: Int
    public let keptByMark: [String: Int]
    public let winsByRule: [PredictionRule: Int]
    public let lossesByRule: [PredictionRule: Int]

    public init(_ records: [OutcomeRecord]) {
        total = 0
        keptWithoutCycling = 0
        keptByMark = [:]
        winsByRule = [:]
        lossesByRule = [:]
    }
}
