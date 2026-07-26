/// One possible "what comes next" insertion for a double-space, e.g. "." or "?".
/// Text-shaped (not an enum of sentence-enders) so future candidates like an
/// opening quote can join without changing the interface.
public struct Candidate: Equatable, Sendable {
    public let text: String

    /// False when the mark closes a token, not the sentence (period after an
    /// abbreviation like "Mr"): the keyboard must not auto-capitalize next.
    public let endsSentence: Bool

    public init(text: String, endsSentence: Bool = true) {
        self.text = text
        self.endsSentence = endsSentence
    }
}

/// Decides what a double-space should insert, given the sentence typed so far.
public struct PunctuationEngine: Sendable {
    private static let whWords: Set<Substring> = [
        "how", "what", "why", "when", "where", "who", "whose", "which",
        "hows", "whats", "wheres", "whos", "whens", "whys",
        "howd", "whatd", "whered", "whod"
    ]

    /// Auxiliary/modal verbs that open a yes-no question whenever they start a
    /// sentence ("was your day good", "can your brother come").
    private static let auxiliaries: Set<Substring> = [
        "does", "did", "am", "are", "is", "was", "were",
        "can", "could", "will", "would", "should", "shall", "may", "might",
        "has", "had"
    ]

    /// Auxiliaries that also head commands/statements ("do your homework",
    /// "have a great day"), so they only signal a question when a pronoun
    /// follows ("do you...", "have you...").
    private static let imperativeCapableAuxiliaries: Set<Substring> = ["do", "have"]

    /// Bare-verb sentence openers that read as invitations in texting
    /// ("want to grab dinner", "wanna come").
    private static let requestVerbs: Set<Substring> = ["want", "wanna"]

    /// Words that mark a sentence as an exclamation wherever they appear
    /// ("congrats on the new job", "omg that view").
    private static let exclamationWords: Set<Substring> = [
        "congrats", "congratulations", "wow", "omg", "yay", "woohoo", "wooo",
        "amazing", "awesome", "incredible", "unbelievable", "insane", "lfg"
    ]

    /// Words a period completes without ending the sentence ("mr", "dr").
    private static let abbreviations: Set<Substring> = [
        "mr", "mrs", "ms", "dr", "prof", "st", "ave", "etc", "vs", "approx"
    ]

    /// Abbreviations with internal dots, matched against the raw last token
    /// BEFORE sentence splitting (the splitter would chop "e.g" at its dot).
    private static let dottedAbbreviations: Set<String> = [
        "e.g", "i.e", "p.m", "a.m", "u.s", "d.c", "ph.d"
    ]

    /// Second words that make a two-word "you ..." sentence a check-in
    /// question ("you good", "you up", "you in").
    private static let checkInWords: Set<Substring> = [
        "good", "up", "ok", "okay", "home", "there", "around", "awake",
        "free", "in", "out", "down", "ready", "close", "coming", "alive"
    ]

    /// Whole sentences that are exclamations by convention (apostrophes are
    /// stripped before matching, so "can't" arrives as "cant").
    private static let exclamationPhrases: Set<String> = [
        "we did it", "i cant believe it", "no way"
    ]

    /// "happy <occasion>" greetings ("happy birthday").
    private static let occasions: Set<Substring> = [
        "birthday", "anniversary", "thanksgiving", "halloween", "easter",
        "holidays", "hanukkah"
    ]

    /// "so <emotion>" openers ("so excited for this").
    private static let emotionWords: Set<Substring> = [
        "excited", "pumped", "stoked", "hyped", "proud", "happy", "psyched"
    ]

    private static let pronouns: Set<Substring> = [
        "i", "you", "we", "they", "he", "she", "it", "u", "ya", "anyone", "anybody"
    ]

    /// Sentence-final words that turn a statement into a tag question
    /// ("you're coming tonight right").
    private static let trailingTags: Set<Substring> = [
        "right", "ok", "okay", "huh", "eh", "yeah"
    ]

    public init() {}

    /// Returns candidates ranked best-first for the text before the cursor.
    public func candidates(before context: String) -> [Candidate] {
        let rawLastToken = context.lowercased()
            .split(whereSeparator: { $0.isWhitespace }).last.map(String.init) ?? ""
        if Self.dottedAbbreviations.contains(rawLastToken) {
            return [Candidate(text: ".", endsSentence: false),
                    Candidate(text: "?"), Candidate(text: "!")]
        }
        let words = Self.sentenceWords(in: context)
        if words.isEmpty, context.contains(where: { !$0.isWhitespace }) {
            return []
        }
        if let last = words.last, Self.abbreviations.contains(last) {
            return [Candidate(text: ".", endsSentence: false),
                    Candidate(text: "?"), Candidate(text: "!")]
        }
        if let first = words.first {
            if Self.whWords.contains(first) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if Self.auxiliaries.contains(first) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if Self.imperativeCapableAuxiliaries.contains(first), words.count > 1,
               Self.pronouns.contains(words[1]) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if Self.requestVerbs.contains(first) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if let last = words.last, words.count > 1, Self.trailingTags.contains(last) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if (first == "you" || first == "u"), words.count == 2,
               Self.checkInWords.contains(words[1]) {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if first == "any" {
                return [Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")]
            }
            if words.contains(where: { Self.exclamationWords.contains($0) })
                || Self.exclamationPhrases.contains(words.joined(separator: " "))
                || (first == "happy" && words.count > 1 && Self.occasions.contains(words[1]))
                || (first == "so" && words.count > 1 && Self.emotionWords.contains(words[1]))
                || (first == "lets" && words.count > 1 && words[1].hasPrefix("go")) {
                return [Candidate(text: "!"), Candidate(text: "."), Candidate(text: "?")]
            }
        }
        return [Candidate(text: "."), Candidate(text: "?"), Candidate(text: "!")]
    }

    /// Words of the sentence being typed (text after the last terminal mark),
    /// lowercased with apostrophes stripped ("What's" -> "whats") so straight
    /// and curly apostrophe forms hit the same word sets.
    private static func sentenceWords(in context: String) -> [Substring] {
        let current = context.split(omittingEmptySubsequences: false,
                                    whereSeparator: { ".!?".contains($0) }).last ?? ""
        let normalized = current.lowercased().filter { $0 != "'" && $0 != "\u{2019}" }
        return normalized[...].split(whereSeparator: { $0.isWhitespace })
    }
}
