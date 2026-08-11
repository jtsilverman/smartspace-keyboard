/// Visual role of a key cap. Stock colors keys by role: letters and space
/// are light caps, function keys are grey, return carries action states.
public enum KeyRole: Equatable, Sendable {
    case letter, function, space, returnKey

    /// Classifies a layout cell id ("q", "__shift", "__space", ...).
    public static func role(forCellID id: String) -> KeyRole {
        switch id {
        case "__space": return .space
        case "__return": return .returnKey
        default: return id.hasPrefix("__") ? .function : .letter
        }
    }
}

/// Stock cap colors and chrome. Values: KeyboardKit 9.9.1, the
/// reverse-engineered stock replica (research 2026-08-10). Letters and
/// space are the light level, function keys the grey level; a press swaps
/// the levels. Dark caps are translucent whites over the system blur, so
/// the extension's background must stay clear.
public enum StockKeyTheme {
    public static func fill(role: KeyRole, dark: Bool, pressed: Bool) -> RGBA {
        let letterLevel = (role == .letter || role == .space) != pressed
        if dark {
            return RGBA(red: 1, green: 1, blue: 1, alpha: letterLevel ? 0.30 : 0.10)
        }
        if letterLevel {
            return RGBA(red: 1, green: 1, blue: 1, alpha: pressed ? 1 : 0.95)
        }
        // #ABB1BA, the stock function-key grey.
        return RGBA(red: 171.0 / 255, green: 177.0 / 255, blue: 186.0 / 255,
                    alpha: pressed ? 1 : 0.95)
    }

    /// Active shift (one-shot or caps lock): opaque white cap, black glyph.
    public static let shiftActiveFill = RGBA(red: 1, green: 1, blue: 1)

    /// Action return types (Search, Go, Send...) tint system blue.
    public static func returnActionFill(dark: Bool) -> RGBA {
        dark ? RGBA(red: 10.0 / 255, green: 132.0 / 255, blue: 1)
             : RGBA(red: 0, green: 122.0 / 255, blue: 1)
    }

    /// Pressed action return: white/black legend in light, flat function
    /// grey in dark (the blue never dims, it swaps).
    public static func returnActionPressedFill(dark: Bool) -> RGBA {
        dark ? RGBA(red: 71.0 / 255, green: 71.0 / 255, blue: 71.0 / 255)
             : RGBA(red: 1, green: 1, blue: 1)
    }

    /// The soft pill behind the bar candidate a commit would apply.
    /// Dark value approximates stock's grey (medium confidence).
    public static let candidatePillCornerRadius: Double = 4
    public static func candidatePillFill(dark: Bool) -> RGBA {
        RGBA(red: 1, green: 1, blue: 1, alpha: dark ? 0.2 : 0.5)
    }

    /// Callout fill: the balloon covers keys, so it is opaque -- white in
    /// light, the flat dark letter cap in dark.
    public static func balloonFill(dark: Bool) -> RGBA {
        dark ? RGBA(red: 107.0 / 255, green: 107.0 / 255, blue: 107.0 / 255)
             : RGBA(red: 1, green: 1, blue: 1)
    }

    /// The hard 1pt drop under every cap; blur 0.
    public static let shadowOffsetY: Double = 1
    public static func shadowColor(dark: Bool) -> RGBA {
        RGBA(red: 0, green: 0, blue: 0, alpha: dark ? 0.70 : 0.30)
    }
}

/// Legend typography per key label, stock sizes.
public enum KeyLegend {
    public static let iconPointSize: Double = 20

    public static func pointSize(for title: String) -> Double {
        switch title {
        case "ABC": return 15
        case "123": return 16
        case "#+=": return 14
        default:
            guard title.count == 1 else { return 16 }
            return usesLightWeight(title) ? 26 : 23
        }
    }

    /// Only lowercase letter legends render in the light weight.
    public static func usesLightWeight(_ title: String) -> Bool {
        title.count == 1 && title != title.uppercased()
    }
}

/// A color as plain numbers (0...1), UIKit-free. The controller maps
/// RGBA to UIColor; the engine owns the values so they stay testable.
public struct RGBA: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}
