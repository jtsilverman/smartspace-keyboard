/// Stock callout geometry: the key-preview balloon and the long-press
/// alternates callout. Values: KeyboardKit Callouts source
/// (reverse-engineered stock replica, research 2026-08-10). The balloon
/// fuses with the key cap below it; the controller draws the path from
/// these numbers and holds no constant of its own.
public enum CalloutGeometry {
    public static let overhangPerSide: Double = 0
    public static func bubbleWidth(keyWidth: Double) -> Double { keyWidth }

    public static let bubbleHeight: Double = 0
    public static let neckHeight: Double = 0
    public static let bubbleCornerRadius: Double = 0
    public static let neckCurveWidth: Double = 0

    public static let previewFontSize: Double = 0
    /// Seconds the balloon stays visible after a fast tap.
    public static let minimumDwell: Double = 0

    public static let alternateItemMaxSize: Double = 0
    public static let alternateFontSize: Double = 0
    public static let selectedCornerRadius: Double = 0
}
