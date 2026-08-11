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

    /// Points the balloon keeps clear of the screen edges.
    public static let screenMargin: Double = 2

    /// Overhang split for a key near a screen edge: the 26pt total holds
    /// while the clipped side hands its excess to the other (stock skews
    /// the bubble; it never clamps it off-center).
    public static func overhangs(keyMinX: Double, keyWidth: Double, screenWidth: Double)
        -> (left: Double, right: Double) {
        let total = 2 * overhangPerSide
        let maxLeft = max(0, keyMinX - screenMargin)
        let maxRight = max(0, screenWidth - screenMargin - keyMinX - keyWidth)
        let left = min(maxLeft, total - min(overhangPerSide, maxRight))
        let right = min(maxRight, total - left)
        return (left: left, right: right)
    }

    public static let bubbleHeight: Double = 55
    public static let neckHeight: Double = 15
    public static let bubbleCornerRadius: Double = 10
    public static let neckCurveWidth: Double = 8

    public static let previewFontSize: Double = 34
    /// Seconds the balloon stays visible after a fast tap.
    public static let minimumDwell: Double = 0.05

    /// True when the key sits in the right half: the callout extends
    /// leading (toward the screen center) with the item order reversed.
    public static func alternatesGrowLeading(keyMinX: Double, screenWidth: Double) -> Bool {
        false
    }

    public static let alternateItemMaxSize: Double = 50
    public static let alternateFontSize: Double = 20
    public static let selectedCornerRadius: Double = 10
}
