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
    /// iOS 26 Liquid Glass chrome (KeyboardKit 9.9 liquid values,
    /// medium-high confidence): harder rounding, no drop shadow,
    /// glassier fills.
    public static func capCornerRadius(liquidGlass: Bool) -> Double {
        liquidGlass ? 9 : StockLayoutMetrics.capCornerRadius
    }

    public static func hasShadow(liquidGlass: Bool) -> Bool { !liquidGlass }

    public static func fill(role: KeyRole, dark: Bool, pressed: Bool,
                            liquidGlass: Bool = false) -> RGBA {
        if liquidGlass {
            // Pressed keeps the idle color at 0.6 alpha; dark idles run
            // at 0.55 of the iOS 18 alpha. No level swap.
            let idle = fill(role: role, dark: dark, pressed: false)
            let scale = (dark ? 0.55 : 1) * (pressed ? 0.6 : 1)
            return RGBA(red: idle.red, green: idle.green, blue: idle.blue,
                        alpha: idle.alpha * scale)
        }
        let letterLevel = (role == .letter || role == .space) != pressed
        if dark {
            return RGBA(red: 1, green: 1, blue: 1, alpha: letterLevel ? 0.30 : 0.10)
        }
        // iOS 26 paints every idle cap white; a pixel scan of stock across
        // nine iPhone 16/17 simulators (2026-08-18) read 255,255,255 at the
        // centre of shift, delete, 123, emoji and return. The grey survives
        // only as the pressed state of a letter, where stock still swaps the
        // two levels under the key-pop bubble.
        let pressedLetter = (role == .letter || role == .space) && pressed
        if pressedLetter {
            // #ABB1BA, the stock pressed-letter grey.
            return RGBA(red: 171.0 / 255, green: 177.0 / 255, blue: 186.0 / 255)
        }
        return RGBA(red: 1, green: 1, blue: 1, alpha: pressed ? 1 : 0.95)
    }

    /// Active shift (one-shot or caps lock): opaque white cap, black glyph.
    /// The keyboard's own backdrop, behind every key and every gutter.
    /// Stock paints this opaque: over a red host app the stock backdrop
    /// reads the same RGB as over a white one (iPhone 17, iOS 26.3,
    /// screenshot measure 2026-08-18). Ours must paint it too. A view with
    /// no visible background takes no touch, so the 6pt gutter between
    /// every pair of caps went dead (EdgeSweepTests, 2026-08-18).
    public static func keyboardBackdrop(dark: Bool) -> RGBA {
        dark ? RGBA(red: 23.0 / 255, green: 23.0 / 255, blue: 23.0 / 255)
             : RGBA(red: 226.0 / 255, green: 228.0 / 255, blue: 232.0 / 255)
    }

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
    /// Measured from the stock icons' ink boxes (pixel scan 2026-08-18,
    /// iPhone 17): shift 20.0 x 17.33pt, delete 20.33 x 17.0, emoji 19 x 19,
    /// return 19.67 x 17.0. Every one is 0.745 of the 20pt rendering this
    /// replaced, which puts stock at 15pt.
    public static let iconPointSize: Double = 15

    /// Stock sits a letter legend above the cap's centre: measured 15.33pt
    /// from the cap top against a centred 17.0pt (pixel scan 2026-08-18,
    /// iPhone 17). A bottom inset of twice the gap re-centres it, since the
    /// cap centres its content. Word and layer labels stay centred.
    public static func legendBottomInset(for title: String) -> Double {
        title.count == 1 ? 3.33 : 0
    }

    public static func pointSize(for title: String) -> Double {
        switch title {
        case "ABC": return 15
        case "123": return 17   // measured ink 27.33 x 13.33pt
        case "#+=": return 14
        default:
            guard title.count == 1 else { return 16 }
            // Lowercase measured at 25pt regular (pixel scan 2026-08-18):
            // stock's x-height is 12.67pt and its stroke carries 14% more
            // ink than the 26pt light rendering this replaced.
            return title != title.uppercased() ? 25 : 23
        }
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
