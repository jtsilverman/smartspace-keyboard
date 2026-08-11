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

// Fill values from KeyboardKit 9.9.1 (reverse-engineered stock replica;
// research 2026-08-10, high confidence): light letters #FFFFFF @0.95 idle,
// function keys #ABB1BA @0.95; dark caps are translucent whites over the
// system keyboard blur (30% letters, 10% function). A press swaps the
// two levels; pressed caps are opaque.

private let greyCap = RGBA(red: 171.0 / 255, green: 177.0 / 255, blue: 186.0 / 255, alpha: 0.95)

@Test func lightCapsMatchStock() {
    #expect(StockKeyTheme.fill(role: .letter, dark: false, pressed: false)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.95))
    #expect(StockKeyTheme.fill(role: .function, dark: false, pressed: false) == greyCap)
    #expect(StockKeyTheme.fill(role: .space, dark: false, pressed: false)
            == StockKeyTheme.fill(role: .letter, dark: false, pressed: false))
    #expect(StockKeyTheme.fill(role: .returnKey, dark: false, pressed: false) == greyCap)
}

@Test func aPressSwapsTheTwoLevels() {
    #expect(StockKeyTheme.fill(role: .letter, dark: false, pressed: true)
            == RGBA(red: 171.0 / 255, green: 177.0 / 255, blue: 186.0 / 255))
    #expect(StockKeyTheme.fill(role: .function, dark: false, pressed: true)
            == RGBA(red: 1, green: 1, blue: 1))
}

@Test func darkCapsAreTranslucentWhitesOverTheBlur() {
    #expect(StockKeyTheme.fill(role: .letter, dark: true, pressed: false)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.30))
    #expect(StockKeyTheme.fill(role: .function, dark: true, pressed: false)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.10))
    #expect(StockKeyTheme.fill(role: .letter, dark: true, pressed: true)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.10))
    #expect(StockKeyTheme.fill(role: .function, dark: true, pressed: true)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.30))
}

@Test func activeShiftIsOpaqueWhiteInBothSchemes() {
    #expect(StockKeyTheme.shiftActiveFill == RGBA(red: 1, green: 1, blue: 1))
}

@Test func actionReturnTintsSystemBlue() {
    #expect(StockKeyTheme.returnActionFill(dark: false)
            == RGBA(red: 0, green: 122.0 / 255, blue: 1))
    #expect(StockKeyTheme.returnActionFill(dark: true)
            == RGBA(red: 10.0 / 255, green: 132.0 / 255, blue: 1))
    // Pressed: white/black in light, function-grey flat in dark.
    #expect(StockKeyTheme.returnActionPressedFill(dark: false)
            == RGBA(red: 1, green: 1, blue: 1))
    #expect(StockKeyTheme.returnActionPressedFill(dark: true)
            == RGBA(red: 71.0 / 255, green: 71.0 / 255, blue: 71.0 / 255))
}

@Test func balloonFillIsTheFlatCapColor() {
    // The balloon covers keys, so it must be opaque: white in light,
    // KeyboardKit's flat dark letter cap #6B6B6B in dark.
    #expect(StockKeyTheme.balloonFill(dark: false) == RGBA(red: 1, green: 1, blue: 1))
    #expect(StockKeyTheme.balloonFill(dark: true)
            == RGBA(red: 107.0 / 255, green: 107.0 / 255, blue: 107.0 / 255))
}

@Test func capShadowIsAHardOnePointDrop() {
    #expect(StockKeyTheme.shadowOffsetY == 1)
    #expect(StockKeyTheme.shadowColor(dark: false) == RGBA(red: 0, green: 0, blue: 0, alpha: 0.30))
    #expect(StockKeyTheme.shadowColor(dark: true) == RGBA(red: 0, green: 0, blue: 0, alpha: 0.70))
}

// Legend typography (KeyboardAction+ButtonFont.swift): lowercase letters
// 26pt light, uppercase letters and digits/symbols 23pt regular, layer
// labels ABC 15 / 123 16 / #+= 14, word keys (space, return, Search) 16,
// SF Symbol keys 20pt.

@Test func legendSizesMatchStock() {
    #expect(KeyLegend.pointSize(for: "q") == 26)
    #expect(KeyLegend.usesLightWeight("q"))
    #expect(KeyLegend.pointSize(for: "Q") == 23)
    #expect(!KeyLegend.usesLightWeight("Q"))
    #expect(KeyLegend.pointSize(for: "1") == 23)
    #expect(KeyLegend.pointSize(for: ".") == 23)
    #expect(KeyLegend.pointSize(for: "ABC") == 15)
    #expect(KeyLegend.pointSize(for: "123") == 16)
    #expect(KeyLegend.pointSize(for: "#+=") == 14)
    #expect(KeyLegend.pointSize(for: "Search") == 16)
    #expect(!KeyLegend.usesLightWeight("Search"))
    #expect(KeyLegend.iconPointSize == 20)
}
