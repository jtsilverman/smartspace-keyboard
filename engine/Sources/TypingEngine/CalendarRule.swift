/// Capitalizes weekday and month names typed lowercase, at word commit.
/// Curated the same way as ContractionRule: only forms whose lowercase
/// reading is not a common word. "march" (verb) and "may" (auxiliary) are
/// excluded -- miscapitalizing running text is the expensive failure.
public enum CalendarRule {
    private static let names: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday",
        "saturday", "sunday",
        "january", "february", "april", "june", "july", "august",
        "september", "october", "november", "december",
    ]

    /// The capitalized form of an all-lowercase calendar name, or nil.
    public static func transform(_ word: String) -> String? {
        guard names.contains(word), let first = word.first else { return nil }
        return first.uppercased() + word.dropFirst()
    }
}
