import Testing
import TypingEngine

// Stock colors keys by role: letters and space are light caps, function
// keys (shift, delete, 123, emoji, globe) are grey, return carries its
// own action states. The cell ids come from StockLayoutMetrics.cells.

@Test func characterCellsAreLetters() {
    for id in ["q", "m", "a", "1", "0", ".", "'", "\u{20AC}"] {
        #expect(KeyRole.role(forCellID: id) == .letter, "id \(id)")
    }
}

@Test func functionCellsAreFunction() {
    for id in ["__shift", "__delete", "__layer", "__emoji", "__globe"] {
        #expect(KeyRole.role(forCellID: id) == .function, "id \(id)")
    }
}

@Test func spaceIsItsOwnRole() {
    #expect(KeyRole.role(forCellID: "__space") == .space)
}

@Test func returnIsItsOwnRole() {
    #expect(KeyRole.role(forCellID: "__return") == .returnKey)
}
