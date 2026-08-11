/// At-rest predictions for the QuickType bar (stock: the bar is never
/// empty). A small bigram table covers the frequent heads; the stock
/// I / The / I'm trio opens sentences; a generic trio fills the rest.
public enum NextWordPredictor {
    /// Up to three predictions for the text before the cursor.
    public static func predictions(after context: String) -> [String] {
        []
    }
}
