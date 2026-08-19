/// At-rest predictions for the QuickType bar (stock: the bar is never
/// empty). A small bigram table covers the frequent heads; the stock
/// I / The / I'm trio opens sentences; a generic trio fills the rest.
public enum NextWordPredictor {
    /// Up to three predictions for the text before the cursor.
    public static func predictions(after context: String) -> [String] {
        // Predictions describe the NEXT word: a trailing partial word
        // belongs to the completion bar, so it is stripped first.
        var rest = Substring(context)
        while let last = rest.last, last.isLetter || last == "'" || last == "\u{2019}" {
            rest.removeLast()
        }
        let base = String(rest)
        if CapitalizationRule.shouldCapitalize(before: base) {
            return sentenceTrio
        }
        let head = lastWord(of: base)
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
        return bigrams[head] ?? fallbackTrio
    }

    /// Stock shows I / The / I'm on an empty field and after enders.
    static let sentenceTrio = ["I", "The", "I\u{2019}m"]
    /// Head unknown: stock still fills the bar; these are the highest
    /// frequency English continuations.
    static let fallbackTrio = ["the", "to", "and"]

    private static func lastWord(of context: String) -> String {
        var rest = Substring(context)
        while rest.last == " " { rest.removeLast() }
        var word = ""
        while let last = rest.last, last.isLetter || last == "'" || last == "\u{2019}" {
            word.insert(last, at: word.startIndex)
            rest.removeLast()
        }
        return word
    }

    /// Frequent English bigram heads -> three continuations, most likely
    /// first. Casing is display casing ("I", "York" stay capital).
    static let bigrams: [String: [String]] = [
        "i": ["am", "will", "have"],
        "you": ["are", "can", "have"],
        "the": ["first", "same", "best"],
        "to": ["be", "get", "see"],
        "a": ["few", "lot", "new"],
        "and": ["I", "the", "then"],
        "of": ["the", "my", "course"],
        "in": ["the", "a", "my"],
        "it": ["is", "was", "will"],
        "is": ["a", "the", "not"],
        "that": ["is", "was", "I"],
        "for": ["the", "a", "me"],
        "on": ["the", "my", "a"],
        "are": ["you", "we", "the"],
        "with": ["the", "my", "a"],
        "was": ["a", "the", "not"],
        "be": ["a", "the", "able"],
        "this": ["is", "was", "week"],
        "have": ["a", "to", "been"],
        "at": ["the", "least", "a"],
        "not": ["sure", "a", "the"],
        "we": ["are", "can", "will"],
        "he": ["is", "was", "will"],
        "she": ["is", "was", "will"],
        "they": ["are", "were", "will"],
        "my": ["own", "best", "first"],
        "your": ["own", "best", "first"],
        "so": ["I", "much", "that"],
        "what": ["is", "are", "do"],
        "can": ["you", "I", "we"],
        "will": ["be", "not", "you"],
        "just": ["a", "got", "wanted"],
        "do": ["you", "not", "it"],
        "me": ["know", "a", "to"],
        "like": ["a", "the", "to"],
        "time": ["to", "for", "of"],
        "no": ["problem", "one", "way"],
        "good": ["morning", "luck", "to"],
        "how": ["are", "is", "do"],
        "about": ["the", "it", "a"],
        "get": ["a", "the", "it"],
        "see": ["you", "the", "it"],
        "know": ["what", "if", "that"],
        "going": ["to", "on", "out"],
        "want": ["to", "a", "it"],
        "let": ["me", "us", "you"],
        "thank": ["you", "God", "goodness"],
        "thanks": ["for", "so", "again"],
        "love": ["you", "it", "the"],
        "if": ["you", "I", "it"],
        "when": ["I", "you", "the"],
        "but": ["I", "it", "the"],
        "or": ["the", "a", "not"],
        "as": ["a", "the", "well"],
        "from": ["the", "my", "a"],
        "by": ["the", "a", "my"],
        "up": ["to", "and", "with"],
        "out": ["of", "there", "to"],
        "all": ["the", "of", "day"],
        "there": ["is", "are", "was"],
        "been": ["a", "to", "there"],
        "one": ["of", "day", "more"],
        "would": ["be", "you", "like"],
        "could": ["be", "you", "not"],
        "should": ["be", "I", "we"],
        "did": ["you", "not", "the"],
        "had": ["a", "to", "been"],
        "has": ["been", "a", "to"],
        "were": ["you", "not", "the"],
        "am": ["not", "going", "so"],
        "an": ["hour", "idea", "email"],
        "new": ["one", "year", "phone"],
        "some": ["of", "time", "more"],
        "more": ["than", "of", "time"],
        "very": ["good", "much", "nice"],
        "really": ["good", "like", "want"],
        "right": ["now", "away", "here"],
        "now": ["I", "that", "and"],
        "then": ["I", "we", "the"],
        "here": ["is", "and", "for"],
        "today": ["I", "and", "is"],
        "tomorrow": ["morning", "and", "at"],
        "tonight": ["at", "and", "I"],
        "morning": ["I", "and", "to"],
        "night": ["and", "I", "at"],
        "day": ["of", "and", "to"],
        "week": ["and", "of", "I"],
        "next": ["week", "time", "to"],
        "last": ["night", "week", "time"],
        "first": ["time", "of", "one"],
        "work": ["on", "and", "tomorrow"],
        "home": ["and", "now", "from"],
        "school": ["and", "tomorrow", "today"],
        "dinner": ["at", "with", "tonight"],
        "lunch": ["at", "with", "today"],
        "meeting": ["at", "with", "tomorrow"],
        "call": ["me", "you", "the"],
        "text": ["me", "you", "when"],
        "send": ["me", "you", "the"],
        "got": ["a", "the", "it"],
        "make": ["a", "sure", "it"],
        "sure": ["you", "that", "to"],
        "need": ["to", "a", "you"],
        "think": ["I", "about", "it"],
        "say": ["that", "I", "the"],
        "go": ["to", "out", "home"],
        "come": ["over", "to", "back"],
        "back": ["to", "home", "in"],
        "way": ["to", "of", "too"],
        "too": ["much", "many", "late"],
        "much": ["better", "more", "of"],
        "still": ["have", "not", "in"],
        "even": ["though", "if", "more"],
        "also": ["have", "a", "the"],
        "because": ["I", "it", "of"],
        "after": ["the", "I", "a"],
        "before": ["I", "the", "we"],
        "over": ["the", "there", "to"],
        "again": ["and", "soon", "tomorrow"],
        "soon": ["as", "and", "I"],
        "maybe": ["we", "I", "a"],
        "probably": ["not", "the", "a"],
        "definitely": ["not", "a", "the"],
        "sorry": ["for", "I", "about"],
        "hello": ["there", "I", "and"],
        "hey": ["there", "I", "how"],
        "hi": ["there", "I", "how"],
        "ok": ["I", "so", "then"],
        "okay": ["I", "so", "then"],
        "yes": ["I", "it", "please"],
        "please": ["let", "send", "do"],
        "great": ["job", "to", "day"],
        "happy": ["birthday", "to", "for"],
        "miss": ["you", "the", "it"],
        "talk": ["to", "about", "soon"],
        "later": ["today", "tonight", "and"],
        "minutes": ["and", "late", "away"],
        "hour": ["and", "or", "ago"],
        "i'm": ["not", "going", "so"],
        "i'll": ["be", "get", "let"],
        "i've": ["been", "got", "never"],
        "i'd": ["like", "love", "say"],
        "don't": ["know", "think", "want"],
        "can't": ["wait", "believe", "do"],
        "it's": ["a", "not", "been"],
        "that's": ["a", "not", "what"],
        "what's": ["the", "up", "your"],
        "let's": ["go", "do", "get"],
        "won't": ["be", "have", "let"],
        "didn't": ["know", "get", "have"],
        "you're": ["going", "not", "welcome"],
        "we're": ["going", "not", "all"],
        "they're": ["not", "going", "all"],
    ]
}
