/// Stock keyboard geometry (stock-parity AC 1): cell frames copied from an
/// AX dump of the real stock keyboard on the 402pt device class, expressed
/// so the letter grid rescales to other widths. Cells are touch zones that
/// tile each row edge-to-edge; the visible key is the cell minus visual
/// insets (the renderer's business).

public struct LayoutCell: Equatable, Sendable {
    public let id: String
    public let frame: Rect
    public init(id: String, frame: Rect) {
        self.id = id
        self.frame = frame
    }
}

public enum StockLayoutMetrics {
    /// Stock steps its vertical metrics by device class instead of scaling
    /// them with width: 54pt rows with 43pt caps at 390, 393 and 402pt, then
    /// 56pt rows with 45pt caps at 420, 430 and 440pt (pixel scan
    /// 2026-08-18, nine iPhone 16/17 simulators on iOS 26.3.1).
    public static let largeClassMinWidth: Double = 420

    public static func rowPitch(width: Double) -> Double {
        width >= largeClassMinWidth ? 56 : 54
    }

    public static func keyAreaHeight(width: Double) -> Double {
        4 * rowPitch(width: width)
    }
    /// Side inset derived from the measured visible caps (screenshot pixel
    /// scan 2026-08-18 across nine iPhone 16/17 simulators: first cap x
    /// 6.67, 6pt of ground between caps, cap width 33.33 at 402pt), which
    /// are ground truth over the AX cell frames' rounding.
    public static let sideInset: Double = 3.67

    /// Visible key cap inside its touch cell, measured from the same scan:
    /// cap top sits 1pt below the cell top and the cell hangs 10pt lower
    /// than the key you see, so the cap is 43pt tall in a 54pt row and 45pt
    /// in a 56pt row. 3.33pt of gutter on each side (6.67pt between caps).
    public static let capInsetTop: Double = 1
    public static let capInsetBottom: Double = 10
    public static let capInsetSide: Double = 3
    /// Stock cap corner radius at this device class.
    public static let capCornerRadius: Double = 5

    public static func capFrame(in cell: Rect) -> Rect {
        Rect(x: cell.x + capInsetSide,
             y: cell.y + capInsetTop,
             width: cell.width - 2 * capInsetSide,
             height: cell.height - capInsetTop - capInsetBottom)
    }

    /// Function-key constants measured at 402pt, scaled by width/402.
    private struct FunctionKeys {
        let shiftWidth: Double
        let deleteX: Double
        let layerWidth: Double
        let emojiX: Double
        let emojiWidth: Double
        let spaceX: Double
        let returnX: Double
        let returnWidth: Double
        init(width: Double) {
            let k = width / 402
            shiftWidth = 51.33 * k
            deleteX = width - 55 * k
            layerWidth = 49.33 * k
            emojiX = 53 * k
            emojiWidth = 49.33 * k
            spaceX = 102.33 * k
            returnX = width - 102.33 * k
            returnWidth = 99 * k
        }
    }

    /// Cell frames for a 3-row character plane plus the synthesized bottom
    /// row. Function cells use the "__" prefix KeyTouchSurface passes
    /// through. y = 0 is the top of the key area.
    public static func cells(width: Double, plane: [[String]]) -> [LayoutCell] {
        let pitch = (width - 2 * sideInset) / 10
        let fn = FunctionKeys(width: width)
        var out: [LayoutCell] = []
        let rowPitch = self.rowPitch(width: width)

        func row(_ keys: [String], y: Double, x0: Double, pitch: Double) {
            for (i, key) in keys.enumerated() {
                out.append(LayoutCell(id: key, frame: Rect(
                    x: x0 + Double(i) * pitch, y: y, width: pitch, height: rowPitch)))
            }
        }

        // Rows 1-2: full-width grids; a 9-key row indents half a cell.
        for (index, keys) in plane.prefix(2).enumerated() {
            let x0 = sideInset + (keys.count == 9 ? pitch / 2 : 0)
            row(keys, y: Double(index) * rowPitch, x0: x0, pitch: pitch)
        }

        // Row 3: leading function cell, characters, delete.
        let y3 = 2 * rowPitch
        out.append(LayoutCell(id: "__shift", frame: Rect(
            x: sideInset, y: y3, width: fn.shiftWidth, height: rowPitch)))
        out.append(LayoutCell(id: "__delete", frame: Rect(
            x: fn.deleteX, y: y3, width: fn.shiftWidth, height: rowPitch)))
        let row3 = plane[2]
        if row3.count == 7 {
            // Letters keep the grid pitch, centered between the flanks.
            row(row3, y: y3, x0: sideInset + fn.shiftWidth + 7.67 * (width / 402), pitch: pitch)
        } else {
            // Punctuation rows divide the space between the flanks evenly.
            let x0 = sideInset + fn.shiftWidth + 7.67 * (width / 402)
            let available = fn.deleteX - x0 - 7.67 * (width / 402)
            row(row3, y: y3, x0: x0, pitch: available / Double(row3.count))
        }

        // Bottom row: layer, emoji, space, return.
        let y4 = 3 * rowPitch
        out.append(LayoutCell(id: "__layer", frame: Rect(
            x: sideInset, y: y4, width: fn.layerWidth, height: rowPitch)))
        out.append(LayoutCell(id: "__emoji", frame: Rect(
            x: fn.emojiX, y: y4, width: fn.emojiWidth, height: rowPitch)))
        out.append(LayoutCell(id: "__space", frame: Rect(
            x: fn.spaceX, y: y4, width: fn.returnX - fn.spaceX, height: rowPitch)))
        out.append(LayoutCell(id: "__return", frame: Rect(
            x: fn.returnX, y: y4, width: fn.returnWidth, height: rowPitch)))
        return out
    }
}
