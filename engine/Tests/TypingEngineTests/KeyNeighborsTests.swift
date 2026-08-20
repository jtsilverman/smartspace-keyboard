import Testing
@testable import TypingEngine

/// Vision milestone 5: "sloppy thumbs land on the word stock lands on". A
/// mistyped letter is usually the key next to the one meant, so the corrector
/// needs to know which keys touch. Adjacency is derived from the measured
/// stock geometry, so these expectations are read off the real layout.
@Suite struct KeyNeighborsTests {
    @Test func sideNeighboursInARowAreAdjacent() {
        #expect(KeyNeighbors.areAdjacent("q", "w"))
        #expect(KeyNeighbors.areAdjacent("e", "w"))
        #expect(KeyNeighbors.areAdjacent("n", "m"))
    }

    @Test func keysOneApartInARowAreNotAdjacent() {
        #expect(!KeyNeighbors.areAdjacent("q", "e"))
        #expect(!KeyNeighbors.areAdjacent("a", "f"))
    }

    @Test func keysInTheRowAboveAreAdjacent() {
        // The middle row sits half a cell to the right of the top row, so "a"
        // reaches "q" and "w".
        #expect(KeyNeighbors.areAdjacent("a", "q"))
        #expect(KeyNeighbors.areAdjacent("a", "w"))
        // The bottom row sits a full cell right of the middle row, so this
        // diagonal is a whole step rather than a half one.
        #expect(KeyNeighbors.areAdjacent("h", "n"))
    }

    @Test func keysAcrossTheKeyboardAreNotAdjacent() {
        #expect(!KeyNeighbors.areAdjacent("y", "a"))
        #expect(!KeyNeighbors.areAdjacent("q", "p"))
    }

    @Test func aLetterIsNotItsOwnNeighbour() {
        #expect(!KeyNeighbors.areAdjacent("k", "k"))
    }

    @Test func oneDifferingLetterIsASingleSubstitution() {
        let slip = KeyNeighbors.singleSubstitution("thw", "the")
        #expect(slip?.typed == "w")
        #expect(slip?.meant == "e")
        #expect(KeyNeighbors.singleSubstitution("teh", "the") == nil)
    }
}
