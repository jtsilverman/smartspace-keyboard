/// Visual role of a key cap. Stock colors keys by role: letters and space
/// are light caps, function keys are grey, return carries action states.
public enum KeyRole: Equatable, Sendable {
    case letter, function, space, returnKey

    /// Classifies a layout cell id ("q", "__shift", "__space", ...).
    public static func role(forCellID id: String) -> KeyRole {
        .letter
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
