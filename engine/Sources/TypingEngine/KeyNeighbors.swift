/// Which letter keys touch which, measured from the same stock geometry the
/// keyboard draws (`StockLayoutMetrics`, `KeyboardLayout.letterRows`).
///
/// A mistyped letter is usually a key next to the one meant, so a candidate
/// reached by swapping a letter for its neighbour is a likelier fix than one
/// reached by swapping it for a key across the keyboard. `CorrectionEngine`
/// ranks by that, and refuses a far-key swap on a word it does not know.
public enum KeyNeighbors {
    /// Two cells are neighbours when their centres sit within 1.45 cells of
    /// each other, measured in cells rather than points: a row is 54pt tall
    /// and a cell 39.5pt wide, so a plain circle reaches further sideways
    /// than upward and misses the diagonal above ("a" to "q" sits half a cell
    /// across and a full row up). Normalizing each axis by its own pitch
    /// reaches sideways along a row and diagonally into the rows above and
    /// below, and no further. The bound clears a full diagonal step (1.41
    /// cells, "h" to "n") and stops short of two keys along a row (2 cells).

    private static let adjacency: [Character: Set<Character>] = {
        // Any width gives the same adjacency; the grid scales uniformly.
        let cells = StockLayoutMetrics.cells(width: 402, plane: KeyboardLayout.letterRows)
            .filter { $0.id.count == 1 }
        let pitch = (402 - 2 * StockLayoutMetrics.sideInset) / 10
        let rowPitch = StockLayoutMetrics.rowPitch(width: 402)
        var table: [Character: Set<Character>] = [:]
        for a in cells {
            guard let key = a.id.first else { continue }
            for b in cells where b.id != a.id {
                guard let other = b.id.first else { continue }
                let dx = ((a.frame.x + a.frame.width / 2)
                    - (b.frame.x + b.frame.width / 2)) / pitch
                let dy = ((a.frame.y + a.frame.height / 2)
                    - (b.frame.y + b.frame.height / 2)) / rowPitch
                if (dx * dx + dy * dy).squareRoot() <= 1.45 {
                    table[key, default: []].insert(other)
                }
            }
        }
        return table
    }()

    /// True when the two letters sit next to each other on the keyboard.
    /// A letter is not its own neighbour.
    public static func areAdjacent(_ a: Character, _ b: Character) -> Bool {
        adjacency[Character(a.lowercased())]?.contains(Character(b.lowercased())) == true
    }

    /// The one position where two same-length words differ, or nil when they
    /// differ anywhere else. A single substitution is the fat-finger shape.
    static func singleSubstitution(_ word: String, _ candidate: String)
        -> (typed: Character, meant: Character)? {
        guard word.count == candidate.count else { return nil }
        var found: (Character, Character)?
        for (a, b) in zip(word, candidate) where a != b {
            if found != nil { return nil }
            found = (a, b)
        }
        return found
    }
}
