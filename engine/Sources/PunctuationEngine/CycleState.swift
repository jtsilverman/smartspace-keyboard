/// Tracks the insert-then-cycle interaction after a double-space: each further
/// space tap replaces the inserted mark with the next ranked candidate.
public struct CycleState: Sendable {
    private let candidates: [Candidate]
    private var index = 0

    /// Fails on an empty list -- the engine returns no candidates right after
    /// terminal punctuation, and a cycle over nothing cannot exist.
    public init?(candidates: [Candidate]) {
        guard !candidates.isEmpty else { return nil }
        self.candidates = candidates
    }

    /// The candidate currently inserted in the text.
    public var current: Candidate {
        candidates[index]
    }

    /// Advances to the next candidate (wrapping) and returns it.
    public mutating func advance() -> Candidate {
        index = (index + 1) % candidates.count
        return candidates[index]
    }
}
