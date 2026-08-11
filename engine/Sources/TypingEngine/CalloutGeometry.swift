/// Stock callout geometry: the key-preview balloon and the long-press
/// alternates callout. Values: KeyboardKit Callouts source
/// (reverse-engineered stock replica, research 2026-08-10). The balloon
/// fuses with the key cap below it; the controller draws the path from
/// these numbers and holds no constant of its own.
public enum CalloutGeometry {
    /// 8pt neck curve plus half the 10pt bubble radius.
    public static let overhangPerSide: Double = 13
    public static func bubbleWidth(keyWidth: Double) -> Double {
        keyWidth + 2 * overhangPerSide
    }

    public static let bubbleHeight: Double = 55
    public static let neckHeight: Double = 15
    public static let bubbleCornerRadius: Double = 10
    public static let neckCurveWidth: Double = 8

    public static let previewFontSize: Double = 34
    /// Seconds the balloon stays visible after a fast tap.
    public static let minimumDwell: Double = 0.05

    public static let alternateItemMaxSize: Double = 50
    public static let alternateFontSize: Double = 20
    public static let selectedCornerRadius: Double = 10
}
