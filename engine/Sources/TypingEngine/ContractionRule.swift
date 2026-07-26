/// Fixes apostrophe-less contractions and standalone "i" at word commit,
/// with curly apostrophes. Deliberately curated: words that double as real
/// words (its, ill, well) are never touched -- a misfire there mangles
/// intended text, and the spell checker covers them in Phase 3.
public enum ContractionRule {
    private static let contractions: [String: String] = [
        "i": "I",
        "im": "I\u{2019}m", "ive": "I\u{2019}ve",
        "dont": "don\u{2019}t", "cant": "can\u{2019}t",
        "didnt": "didn\u{2019}t", "doesnt": "doesn\u{2019}t",
        "isnt": "isn\u{2019}t", "wasnt": "wasn\u{2019}t",
        "werent": "weren\u{2019}t", "wouldnt": "wouldn\u{2019}t",
        "couldnt": "couldn\u{2019}t", "shouldnt": "shouldn\u{2019}t",
        "havent": "haven\u{2019}t", "hasnt": "hasn\u{2019}t",
        "hadnt": "hadn\u{2019}t", "arent": "aren\u{2019}t",
        "youre": "you\u{2019}re", "youve": "you\u{2019}ve",
        "theyre": "they\u{2019}re", "theyve": "they\u{2019}ve",
        "weve": "we\u{2019}ve", "whats": "what\u{2019}s",
        "thats": "that\u{2019}s", "theres": "there\u{2019}s",
        "heres": "here\u{2019}s", "hes": "he\u{2019}s", "shes": "she\u{2019}s",
    ]

    /// The corrected form of a committed word, or nil to leave it alone.
    public static func transform(_ word: String) -> String? {
        let key = word.lowercased()
        if let fixed = contractions[key] {
            return recased(fixed, like: word)
        }
        // "i'm"/"i\u{2019}d" typed with their apostrophe still need the
        // capital I and a curly apostrophe.
        if key.hasPrefix("i'") || key.hasPrefix("i\u{2019}") {
            return "I\u{2019}" + word.dropFirst(2)
        }
        return nil
    }

    /// A contraction typed with a leading capital keeps it (Dont -> Don't);
    /// an all-caps word keeps shouting (DONT -> DON'T).
    private static func recased(_ fixed: String, like word: String) -> String {
        if word.count >= 2, word.allSatisfy(\.isUppercase) {
            return fixed.uppercased()
        }
        guard word.first?.isUppercase == true,
              let first = fixed.first, first.isLowercase else { return fixed }
        return first.uppercased() + fixed.dropFirst()
    }
}
