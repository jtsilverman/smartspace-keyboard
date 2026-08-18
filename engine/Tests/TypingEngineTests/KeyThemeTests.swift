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
// every idle light cap is white @0.95, function keys included: iOS 26 
// dropped the grey idle function cap, measured by pixel scan across nine
// iPhone 16/17 simulators (2026-08-18). #ABB1BA survives as the pressed
// letter. Dark caps are translucent whites over the system keyboard blur
// (30% letters, 10% function); a press swaps the two levels.

@Test func lightCapsMatchStock() {
    #expect(StockKeyTheme.fill(role: .letter, dark: false, pressed: false)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.95))
    #expect(StockKeyTheme.fill(role: .function, dark: false, pressed: false)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.95))
    #expect(StockKeyTheme.fill(role: .space, dark: false, pressed: false)
            == StockKeyTheme.fill(role: .letter, dark: false, pressed: false))
    #expect(StockKeyTheme.fill(role: .returnKey, dark: false, pressed: false)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.95))
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

@Test func theBackdropIsOpaqueInBothSchemes() {
    for dark in [false, true] {
        #expect(StockKeyTheme.keyboardBackdrop(dark: dark).alpha == 1,
                "a translucent backdrop takes no touch and the gutters go dead")
    }
    #expect(StockKeyTheme.keyboardBackdrop(dark: false)
            == RGBA(red: 226.0 / 255, green: 228.0 / 255, blue: 232.0 / 255))
    #expect(StockKeyTheme.keyboardBackdrop(dark: true)
            == RGBA(red: 23.0 / 255, green: 23.0 / 255, blue: 23.0 / 255))
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

// iOS 26 Liquid Glass (KeyboardKit 9.9 liquid values, medium-high
// confidence): 9pt corners, no drop shadow, dark fills at 0.55 of the
// iOS 18 alpha, pressed = idle at 0.6 alpha with no level swap.

@Test func liquidGlassRoundsHarderAndDropsTheShadow() {
    #expect(StockKeyTheme.capCornerRadius(liquidGlass: false) == 5)
    #expect(StockKeyTheme.capCornerRadius(liquidGlass: true) == 9)
    #expect(StockKeyTheme.hasShadow(liquidGlass: false))
    #expect(!StockKeyTheme.hasShadow(liquidGlass: true))
}

@Test func liquidGlassFillsGoGlassy() {
    #expect(StockKeyTheme.fill(role: .letter, dark: true, pressed: false, liquidGlass: true)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.30 * 0.55))
    #expect(StockKeyTheme.fill(role: .function, dark: true, pressed: false, liquidGlass: true)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.10 * 0.55))
    #expect(StockKeyTheme.fill(role: .letter, dark: false, pressed: false, liquidGlass: true)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.95))
    // Pressed keeps the idle color at 0.6 alpha; no grey/white swap.
    #expect(StockKeyTheme.fill(role: .letter, dark: false, pressed: true, liquidGlass: true)
            == RGBA(red: 1, green: 1, blue: 1, alpha: 0.95 * 0.6))
}

@Test func candidatePillMatchesStock() {
    // KeyboardKit: white @0.5, corner 4, on the autocorrect candidate.
    // Dark value is a medium-confidence approximation of stock's grey.
    #expect(StockKeyTheme.candidatePillCornerRadius == 4)
    #expect(StockKeyTheme.candidatePillFill(dark: false) == RGBA(red: 1, green: 1, blue: 1, alpha: 0.5))
    #expect(StockKeyTheme.candidatePillFill(dark: true) == RGBA(red: 1, green: 1, blue: 1, alpha: 0.2))
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

// Legend typography. The lowercase letter is measured: a pixel scan of the
// stock keyboard (2026-08-18, iPhone 17) reads a 12.67pt x-height and 14%
// more ink than a 26pt light rendering, which fits 25pt regular. No legend
// uses the light weight. The rest are KeyboardKit replica values: uppercase
// letters and digits/symbols 23pt, layer labels ABC 15 / 123 16 / #+= 14,
// word keys (space, return, Search) 16. The SF Symbol keys and the 123
// label are measured too: 15pt icons and a 17pt "123".

@Test func legendSizesMatchStock() {
    #expect(KeyLegend.pointSize(for: "q") == 25)
    #expect(KeyLegend.pointSize(for: "Q") == 23)
    #expect(KeyLegend.pointSize(for: "1") == 23)
    #expect(KeyLegend.pointSize(for: ".") == 23)
    #expect(KeyLegend.pointSize(for: "ABC") == 15)
    #expect(KeyLegend.pointSize(for: "123") == 17)
    #expect(KeyLegend.pointSize(for: "#+=") == 14)
    #expect(KeyLegend.pointSize(for: "Search") == 16)
    #expect(KeyLegend.iconPointSize == 15)
    #expect(KeyLegend.legendBottomInset(for: "q") == 3.33)
    #expect(KeyLegend.legendBottomInset(for: "123") == 0)
}

// iOS 26 dropped the grey function key: a pixel scan of the stock keyboard
// on nine iPhone 16/17 simulators (2026-08-18) read 255,255,255 at the
// centre of shift, delete, 123, emoji and return, the same white as the
// letter caps. The grey #ABB1BA belonged to iOS 18.
@Test func lightFunctionKeysShareTheLetterWhite() {
    for role in [KeyRole.function, .returnKey, .space] {
        let fn = StockKeyTheme.fill(role: role, dark: false, pressed: false)
        let letter = StockKeyTheme.fill(role: .letter, dark: false, pressed: false)
        #expect(fn.red == letter.red && fn.green == letter.green && fn.blue == letter.blue)
        #expect(fn.alpha == letter.alpha)
    }
}

@Test func lightFunctionKeysStayWhiteUnderLiquidGlass() {
    let fn = StockKeyTheme.fill(role: .function, dark: false, pressed: false, liquidGlass: true)
    let letter = StockKeyTheme.fill(role: .letter, dark: false, pressed: false, liquidGlass: true)
    #expect(fn.red == letter.red && fn.green == letter.green && fn.blue == letter.blue)
}
