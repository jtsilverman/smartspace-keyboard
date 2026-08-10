/// The QWERTY letter grid the keyboard extension renders. Data only; the
/// extension owns buttons and sizing, this owns which letters exist and where.
public enum KeyboardLayout {
    public static let letterRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]

    /// The "123" plane, mirroring the stock layout.
    public static let numberRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'"],
    ]

    /// The "#+=" plane.
    public static let symbolRows: [[String]] = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", "|", "~", "<", ">", "\u{20AC}", "\u{00A3}", "\u{00A5}", "\u{2022}"],
        [".", ",", "?", "!", "'"],
    ]

    /// Long-press alternates, stock-parity for the common accents/currency.
    public static let alternates: [String: [String]] = [
        "a": ["\u{00E0}", "\u{00E1}", "\u{00E2}", "\u{00E4}", "\u{00E6}", "\u{00E3}", "\u{00E5}", "\u{0101}"],
        "e": ["\u{00E8}", "\u{00E9}", "\u{00EA}", "\u{00EB}", "\u{0113}", "\u{0117}", "\u{0119}"],
        "i": ["\u{00EE}", "\u{00EF}", "\u{00ED}", "\u{012B}", "\u{012F}", "\u{00EC}"],
        "o": ["\u{00F4}", "\u{00F6}", "\u{00F2}", "\u{00F3}", "\u{0153}", "\u{00F8}", "\u{014D}", "\u{00F5}"],
        "u": ["\u{00FB}", "\u{00FC}", "\u{00F9}", "\u{00FA}", "\u{016B}"],
        "n": ["\u{00F1}", "\u{0144}"],
        "c": ["\u{00E7}", "\u{0107}", "\u{010D}"],
        "s": ["\u{00DF}", "\u{015B}", "\u{0161}"],
        "y": ["\u{00FF}"],
        "l": ["\u{0142}"],
        "$": ["\u{20AC}", "\u{00A3}", "\u{00A5}", "\u{20A9}"],
        "-": ["\u{2013}", "\u{2014}", "\u{2022}"],
        "\"": ["\u{201C}", "\u{201D}", "\u{201E}", "\u{00AB}", "\u{00BB}"],
        "'": ["\u{2018}", "\u{2019}", "\u{201A}"],
        "?": ["\u{00BF}"],
        "!": ["\u{00A1}"],
    ]
}

public enum ShiftMode: Equatable, Sendable {
    case off, oneShot, capsLock
}

/// The host field's autocapitalization trait, mirrored from UIKit so the
/// engine stays UIKit-free.
public enum AutocapTrait: Equatable, Sendable {
    case none, words, sentences, allCharacters
}

/// Shift state machine: tap arms one-shot, double-tap within the window locks
/// caps, tap while locked releases. Auto-shift arms one-shot at sentence
/// starts via the shared CapitalizationRule.
public struct ShiftState: Sendable {
    public private(set) var mode: ShiftMode = .off
    private var lastTapTime: Double?

    public static let doubleTapWindow: Double = 0.35

    public var isShifted: Bool { mode != .off }

    public init() {}

    /// - Parameter time: tap timestamp for double-tap detection; nil means
    ///   an isolated tap (no double-tap possible).
    public mutating func tapShift(at time: Double? = nil) {
        defer { lastTapTime = time }
        switch mode {
        case .capsLock:
            mode = .off
        case .oneShot:
            if let time, let last = lastTapTime, time - last <= Self.doubleTapWindow {
                mode = .capsLock
            } else {
                mode = .off
            }
        case .off:
            mode = .oneShot
        }
    }

    public mutating func didTypeLetter() {
        if mode == .oneShot { mode = .off }
    }

    /// Arms one-shot where the host field's trait says so; never touches
    /// caps lock or an already-armed one-shot.
    public mutating func armAutoShift(for context: String, trait: AutocapTrait = .sentences) {
        guard mode == .off else { return }
        let arms: Bool
        switch trait {
        case .none:
            arms = false
        case .sentences:
            arms = CapitalizationRule.shouldCapitalize(before: context)
        case .words:
            arms = context.last.map(\.isWhitespace) ?? true
        case .allCharacters:
            arms = true
        }
        if arms { mode = .oneShot }
    }

    /// Arms one-shot unconditionally (except caps lock): for sites that KNOW
    /// a sentence just ended -- a smart-space terminal mark after an
    /// abbreviation ("Ave.") where context re-derivation would say no.
    public mutating func armOneShot() {
        guard mode == .off else { return }
        mode = .oneShot
    }
}

/// Which key plane is showing; transitions mirror the stock keyboard's
/// 123 / #+= / ABC buttons.
public enum KeyboardLayer: Equatable, Sendable {
    case letters, numbers, symbols

    /// The bottom-row key: "123" from letters, "ABC" otherwise.
    public mutating func tapPrimary() {
        self = (self == .letters) ? .numbers : .letters
    }

    /// The shift-position key on non-letter planes: "#+=" from numbers,
    /// "123" from symbols.
    public mutating func tapSecondary() {
        self = (self == .numbers) ? .symbols : .numbers
    }

    /// Stock: a space typed on the 123 / #+= plane flips back to letters.
    public mutating func didTypeSpace() {
        self = .letters
    }
}

/// The label the return key shows for a host field's returnKeyType.
public enum ReturnKeyLabel {
    public static func label(for returnKeyType: String) -> String {
        switch returnKeyType.lowercased() {
        case "search", "google", "yahoo": return "Search"
        case "go": return "Go"
        case "send": return "Send"
        case "done": return "Done"
        case "next": return "Next"
        case "join": return "Join"
        case "route": return "Route"
        case "continue": return "Continue"
        case "emergencycall": return "Emergency Call"
        default: return "return"
        }
    }
}
