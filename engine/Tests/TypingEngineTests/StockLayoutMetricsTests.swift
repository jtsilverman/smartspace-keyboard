import Testing
import TypingEngine

// Stock-parity AC 1: cell frames match the AX-measured stock keyboard on
// the 402pt device class (spec keyboard-stock-parity, dump 2026-07-31).
// Oracle values are the MEASURED stock frames, not recomputed from the
// implementation. Cells are touch zones; y=0 is the top of the key area.

private func cell(_ id: String, _ cells: [LayoutCell]) -> LayoutCell? {
    cells.first(where: { $0.id == id })
}

private func near(_ a: Double, _ b: Double, tol: Double = 0.5) -> Bool {
    abs(a - b) <= tol
}

// Cells are the caps grown by 3pt of gutter on each side, so these origins
// moved with the 2026-08-18 pixel scan: the AX dump that seeded them rounds
// its frames and put every cap up to 1.33pt off stock.
@Test func letterPlaneMatchesMeasuredStockAt402() {
    let cells = StockLayoutMetrics.cells(width: 402, plane: KeyboardLayout.letterRows)
    let q = cell("q", cells)!
    #expect(near(q.frame.x, 3.67) && near(q.frame.y, 0)
            && near(q.frame.width, 39.47) && near(q.frame.height, 54))
    let w = cell("w", cells)!
    #expect(near(w.frame.x, 43.13))
    let a = cell("a", cells)!
    #expect(near(a.frame.x, 23.40) && near(a.frame.y, 54))
    let z = cell("z", cells)!
    #expect(near(z.frame.x, 62.67) && near(z.frame.y, 108))
    let shift = cell("__shift", cells)!
    #expect(near(shift.frame.x, 3.67) && near(shift.frame.width, 51.33)
            && near(shift.frame.y, 108))
    let delete = cell("__delete", cells)!
    #expect(near(delete.frame.x, 347) && near(delete.frame.width, 51.33))
    let layerKey = cell("__layer", cells)!
    #expect(near(layerKey.frame.x, 3.67) && near(layerKey.frame.width, 49.33)
            && near(layerKey.frame.y, 162))
    let emoji = cell("__emoji", cells)!
    #expect(near(emoji.frame.x, 53) && near(emoji.frame.width, 49.33))
    let space = cell("__space", cells)!
    #expect(near(space.frame.x, 102.33) && near(space.frame.width, 197.34))
    let ret = cell("__return", cells)!
    #expect(near(ret.frame.x, 299.67) && near(ret.frame.width, 99))
}

@Test func rowPitchIsExactly54() {
    let cells = StockLayoutMetrics.cells(width: 402, plane: KeyboardLayout.letterRows)
    #expect(cell("q", cells)!.frame.y == 0)
    #expect(cell("a", cells)!.frame.y == 54)
    #expect(cell("z", cells)!.frame.y == 108)
    #expect(cell("__space", cells)!.frame.y == 162)
}

// The visible cap inside a cell: measured 32.83pt wide, 43pt tall, with
// the cell hanging 10pt below it (stock-parity, pixel scan 2026-07-31).
// Re-measured 2026-08-18 by pixel scan on nine iPhone 16/17 simulators: the
// first cap starts 6.67pt from the edge on every width, caps are 33.33pt wide
// at 402pt, and 6pt of ground separates neighbouring caps. The 6.67pt gap
// this test carried came from the AX cell frames, which round.
@Test func capFrameMatchesMeasuredStockCap() {
    let cells = StockLayoutMetrics.cells(width: 402, plane: KeyboardLayout.letterRows)
    let cap = StockLayoutMetrics.capFrame(in: cell("q", cells)!.frame)
    #expect(near(cap.x, 6.67) && near(cap.width, 33.33, tol: 0.2))
    #expect(near(cap.y, 1) && near(cap.height, 43))
    let capW = StockLayoutMetrics.capFrame(in: cell("w", cells)!.frame)
    #expect(near(capW.x - (cap.x + cap.width), 6, tol: 0.2))   // stock gap
}

// The measured cap columns: first cap at 6.67pt, last cap at width - 6.67 -
// capWidth, on every device class (pixel scan 2026-08-18).
@Test func capColumnsMatchTheMeasuredScanOnEveryWidth() {
    let measured: [Double: (last: Double, capWidth: Double)] = [
        402: (362.00, 33.33), 420: (378.33, 35.33),
        430: (387.33, 36.33), 440: (396.33, 37.33),
    ]
    for (width, want) in measured {
        let cells = StockLayoutMetrics.cells(width: width, plane: KeyboardLayout.letterRows)
        let q = StockLayoutMetrics.capFrame(in: cell("q", cells)!.frame)
        let p = StockLayoutMetrics.capFrame(in: cell("p", cells)!.frame)
        #expect(near(q.x, 6.67, tol: 0.4))
        #expect(near(p.x, want.last, tol: 0.4))
        #expect(near(q.width, want.capWidth, tol: 0.4))
    }
}

// Function caps, measured at 402pt: shift and delete 45.3pt wide, the layer
// and emoji keys 43.3pt, space 191.3pt starting at 105.33, return 93pt.
@Test func functionCapsMatchTheMeasuredScanAt402() {
    let cells = StockLayoutMetrics.cells(width: 402, plane: KeyboardLayout.letterRows)
    func cap(_ id: String) -> Rect {
        StockLayoutMetrics.capFrame(in: cell(id, cells)!.frame)
    }
    #expect(near(cap("__shift").x, 6.67, tol: 0.4) && near(cap("__shift").width, 45.33, tol: 0.4))
    #expect(near(cap("__delete").x, 350.0, tol: 0.4) && near(cap("__delete").width, 45.67, tol: 0.4))
    #expect(near(cap("__layer").x, 6.67, tol: 0.4) && near(cap("__layer").width, 43.33, tol: 0.4))
    #expect(near(cap("__emoji").x, 56.0, tol: 0.4) && near(cap("__emoji").width, 43.33, tol: 0.4))
    #expect(near(cap("__space").x, 105.33, tol: 0.4) && near(cap("__space").width, 191.33, tol: 0.4))
    #expect(near(cap("__return").x, 302.67, tol: 0.4) && near(cap("__return").width, 93.0, tol: 0.4))
}

@Test func cellsAbutWithNoDeadGutters() {
    // Stock hit zones tile the row: each letter cell starts where the
    // previous one ends (within rounding).
    let cells = StockLayoutMetrics.cells(width: 402, plane: KeyboardLayout.letterRows)
    let row1 = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"].map { cell($0, cells)! }
    for (lhs, rhs) in zip(row1, row1.dropFirst()) {
        #expect(near(lhs.frame.x + lhs.frame.width, rhs.frame.x, tol: 0.05))
    }
}

@Test func numberPlanePunctuationRowMatchesMeasuredStock() {
    // AX dump of the stock 123 plane (2026-07-31): cells at x 63.67,
    // 119.0, 174.33, 229.67, 285.0, width 55.33, flush against delete.
    // Tolerance 1.5pt: the AX frames round, the visible-cap scan is the
    // tighter oracle and only the letter grid was scanned per-pixel.
    let cells = StockLayoutMetrics.cells(width: 402, plane: KeyboardLayout.numberRows)
    let dot = cell(".", cells)!
    #expect(near(dot.frame.x, 63.67, tol: 1.5) && near(dot.frame.width, 55.33, tol: 1.5)
            && near(dot.frame.y, 108))
    let comma = cell(",", cells)!
    #expect(near(comma.frame.x, 119.0, tol: 1.5))
    let apostrophe = cell("'", cells)!
    #expect(near(apostrophe.frame.x, 285.0, tol: 1.5)
            && near(apostrophe.frame.width, 55.33, tol: 1.5))
    #expect(cell("__delete", cells) != nil && cell("__space", cells) != nil)
}

@Test func widthScalesProportionally() {
    // A 375pt device keeps the same fractions: q pitch = (375-9.33)/10.
    let cells = StockLayoutMetrics.cells(width: 375, plane: KeyboardLayout.letterRows)
    let q = cell("q", cells)!
    let w = cell("w", cells)!
    #expect(near(w.frame.x - q.frame.x, (375.0 - 6.67) / 10, tol: 0.1))
}

// Large-device class (pixel scan 2026-08-18, iOS 26.3.1): stock steps its
// row pitch from 54 to 56 and its cap height from 43 to 45 somewhere between
// 402pt and 420pt. Measured 54/43 at 390, 393 and 402pt; 56/45 at 420, 430
// and 440pt. The insets hold, so the cap follows the pitch.

@Test func rowPitchStepsWithTheDeviceClass() {
    #expect(StockLayoutMetrics.rowPitch(width: 390) == 54)
    #expect(StockLayoutMetrics.rowPitch(width: 402) == 54)
    #expect(StockLayoutMetrics.rowPitch(width: 420) == 56)
    #expect(StockLayoutMetrics.rowPitch(width: 430) == 56)
    #expect(StockLayoutMetrics.rowPitch(width: 440) == 56)
}

@Test func keyAreaHeightIsFourRowsOfTheClassPitch() {
    #expect(StockLayoutMetrics.keyAreaHeight(width: 402) == 216)
    #expect(StockLayoutMetrics.keyAreaHeight(width: 440) == 224)
}

@Test func largeClassRowsSitAtTheMeasuredPitch() {
    for width in [420.0, 430.0, 440.0] {
        let cells = StockLayoutMetrics.cells(width: width, plane: KeyboardLayout.letterRows)
        #expect(cell("q", cells)!.frame.y == 0)
        #expect(cell("a", cells)!.frame.y == 56)
        #expect(cell("z", cells)!.frame.y == 112)
        #expect(cell("__space", cells)!.frame.y == 168)
        #expect(cell("q", cells)!.frame.height == 56)
    }
}

@Test func largeClassCapIsFortyFiveTall() {
    for width in [420.0, 430.0, 440.0] {
        let cells = StockLayoutMetrics.cells(width: width, plane: KeyboardLayout.letterRows)
        let cap = StockLayoutMetrics.capFrame(in: cell("q", cells)!.frame)
        #expect(near(cap.y, 1) && near(cap.height, 45))
    }
}

// Measured stock cap origins on the large class: the first cap starts 6.67pt
// from the edge on every width, and the row-1 caps step by (width - 13.34)/10.
@Test func largeClassCapColumnsMatchTheMeasuredScan() {
    let measured: [Double: (first: Double, last: Double, capWidth: Double)] = [
        420: (6.67, 378.33, 35.33),
        430: (6.67, 387.33, 36.33),
        440: (6.67, 396.33, 37.33),
    ]
    for (width, want) in measured {
        let cells = StockLayoutMetrics.cells(width: width, plane: KeyboardLayout.letterRows)
        let q = StockLayoutMetrics.capFrame(in: cell("q", cells)!.frame)
        let p = StockLayoutMetrics.capFrame(in: cell("p", cells)!.frame)
        #expect(near(q.x, want.first, tol: 1))
        #expect(near(p.x, want.last, tol: 1))
        #expect(near(q.width, want.capWidth, tol: 1))
    }
}
