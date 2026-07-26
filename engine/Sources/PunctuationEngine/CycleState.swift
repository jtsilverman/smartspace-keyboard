/// Tracks the insert-then-cycle interaction after a double-space: each further
/// space tap replaces the inserted mark with the next ranked candidate.
public struct CycleState: Sendable {
    private let candidates: [Candidate]

    public init(candidates: [Candidate]) {
        self.candidates = candidates
    }

    /// The candidate currently inserted in the text.
    public var current: Candidate {
        candidates[0]
    }

    /// Advances to the next candidate and returns it.
    public mutating func advance() -> Candidate {
        candidates[0]
    }
}
