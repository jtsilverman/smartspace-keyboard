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
        RGBA(red: 1, green: 1, blue: 1)
    }

    /// Active shift (one-shot or caps lock): opaque white cap, black glyph.
    public static let shiftActiveFill = RGBA(red: 0, green: 0, blue: 0)

    /// Action return types (Search, Go, Send...) tint system blue.
    public static func returnActionFill(dark: Bool) -> RGBA {
        RGBA(red: 1, green: 1, blue: 1)
    }

    public static func returnActionPressedFill(dark: Bool) -> RGBA {
        RGBA(red: 1, green: 1, blue: 1)
    }

    /// The hard 1pt drop under every cap; blur 0.
    public static let shadowOffsetY: Double = 0
    public static func shadowColor(dark: Bool) -> RGBA {
        RGBA(red: 0, green: 0, blue: 0)
    }
}

/// Legend typography per key label, stock sizes.
public enum KeyLegend {
    public static let iconPointSize: Double = 0

    public static func pointSize(for title: String) -> Double { 0 }

    public static func usesLightWeight(_ title: String) -> Bool { false }
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
