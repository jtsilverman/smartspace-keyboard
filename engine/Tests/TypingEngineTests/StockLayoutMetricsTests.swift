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

@Test func letterPlaneMatchesMeasuredStockAt402() {
    let cells = StockLayoutMetrics.cells(width: 402, plane: KeyboardLayout.letterRows)
    let q = cell("q", cells)!
    #expect(near(q.frame.x, 3.34) && near(q.frame.y, 0)
            && near(q.frame.width, 39.53) && near(q.frame.height, 54))
    let w = cell("w", cells)!
    #expect(near(w.frame.x, 42.87))
    let a = cell("a", cells)!
    #expect(near(a.frame.x, 23.10) && near(a.frame.y, 54))
    let z = cell("z", cells)!
    #expect(near(z.frame.x, 62.33) && near(z.frame.y, 108))
    let shift = cell("__shift", cells)!
    #expect(near(shift.frame.x, 3.34) && near(shift.frame.width, 51.33)
            && near(shift.frame.y, 108))
    let delete = cell("__delete", cells)!
    #expect(near(delete.frame.x, 348) && near(delete.frame.width, 51.33))
    let layerKey = cell("__layer", cells)!
    #expect(near(layerKey.frame.x, 3.34) && near(layerKey.frame.width, 49.33)
            && near(layerKey.frame.y, 162))
    let emoji = cell("__emoji", cells)!
    #expect(near(emoji.frame.x, 54) && near(emoji.frame.width, 49.33))
    let space = cell("__space", cells)!
    #expect(near(space.frame.x, 103.33) && near(space.frame.width, 197.33))
    let ret = cell("__return", cells)!
    #expect(near(ret.frame.x, 300.67) && near(ret.frame.width, 99))
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
@Test func capFrameMatchesMeasuredStockCap() {
    let cells = StockLayoutMetrics.cells(width: 402, plane: KeyboardLayout.letterRows)
    let cap = StockLayoutMetrics.capFrame(in: cell("q", cells)!.frame)
    #expect(near(cap.x, 6.67) && near(cap.width, 32.86))
    #expect(near(cap.y, 1) && near(cap.height, 43))
    let capW = StockLayoutMetrics.capFrame(in: cell("w", cells)!.frame)
    #expect(near(capW.x - (cap.x + cap.width), 6.67))   // stock gap
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
