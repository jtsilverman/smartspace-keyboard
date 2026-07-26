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
        "howd", "whatd", "whered", "whod",
        "wat", "wot", "wats", "wots"
    ]

    /// Auxiliary/modal verbs that open a yes-no question whenever they start a
    /// sentence ("was your day good", "r u meeting them").
    private static let auxiliaries: Set<Substring> = [
        "does", "did", "am", "are", "is", "was", "were", "r",
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

    /// Openers that make a SHORT sentence a warm burst ("hey there",
    /// "yes baby"); longer sentences with these openers are statements.
    private static let greetingOpeners: Set<Substring> = ["hey", "hi", "hello", "yes", "yep"]

    /// Openers that are warm at any length ("thank you so much for coming").
    private static let thanksOpeners: Set<Substring> = ["thanks", "thank", "thx", "ty"]

    private static let pronouns: Set<Substring> = [
        "i", "you", "we", "they", "he", "she", "it", "u", "ya", "anyone", "anybody"
    ]

    /// Sentence-final words that turn a statement into a tag question
    /// ("you're coming tonight right").
    private static let trailingTags: Set<Substring> = [
        "right", "ok", "okay", "huh", "eh", "yeah"
    ]

    /// Clause openers that promise more sentence ("if you're free tomorrow,").
    private static let subordinateOpeners: Set<Substring> = [
        "if", "as", "while", "although", "though", "unless", "since", "once"
    ]

    /// Sentence-starting conjunctions that usually continue with a comma in
    /// texting ("but actually it is,").
    private static let conjunctionOpeners: Set<Substring> = ["and", "but", "also", "plus"]

    /// Verbs of speech that introduce a quotation when they end the sentence
    /// ("she said" -> opening quote).
    private static let sayVerbs: Set<Substring> = ["say", "says", "said", "saying"]

    /// Rank orders per prediction shape; comma and quote never end a sentence.
    private static func ranked(_ order: [String], firstEndsSentence: Bool = true) -> [Candidate] {
        order.enumerated().map { i, text in
            let continuation = (text == "," || text == "\"")
            let ends = continuation ? false : (i == 0 ? firstEndsSentence : true)
            return Candidate(text: text, endsSentence: ends)
        }
    }

    public init() {}

    /// Whether a raw token (dots included: "Mr.", "e.g.", "mr") is a known
    /// abbreviation whose period does not end the sentence. The one shared
    /// abbreviation fact -- TypingEngine's capitalization rule consults this
    /// instead of keeping its own list.
    public static func isKnownAbbreviation(_ rawToken: String) -> Bool {
        var token = rawToken.lowercased()
        if token.hasSuffix(".") { token.removeLast() }
        return Self.abbreviations.contains(token[...]) ||
            Self.dottedAbbreviations.contains(token)
    }

    /// Returns the ranked candidates plus which rule produced them -- the
    /// label outcome records key on for stats and personal re-ranking.
    public func prediction(before context: String) -> Prediction {
        let rawLastToken = context.lowercased()
            .split(whereSeparator: { $0.isWhitespace }).last.map(String.init) ?? ""
        if Self.dottedAbbreviations.contains(rawLastToken) {
            return Prediction(rule: .dottedAbbreviation,
                              candidates: Self.ranked([".", "?", "!", ",", "\""],
                                                      firstEndsSentence: false))
        }

        let sentence = Self.currentSentence(in: context)
        let words = Self.tokens(sentence)
        if words.isEmpty, context.contains(where: { !$0.isWhitespace }) {
            return Prediction(rule: .terminalGuard, candidates: [])
        }
        if let last = words.last, Self.abbreviations.contains(last) {
            return Prediction(rule: .abbreviation,
                              candidates: Self.ranked([".", "?", "!", ",", "\""],
                                                      firstEndsSentence: false))
        }

        // A question can hide in the last comma-separated clause
        // ("just got home babe, are you still awake").
        let clauseWords = Self.tokens(sentence.split(separator: ",").last ?? sentence)
        if Self.isQuestion(words) || Self.isQuestion(clauseWords) {
            return Prediction(rule: .question,
                              candidates: Self.ranked(["?", ".", "!", ",", "\""]))
        }
        if Self.isCommaContinuation(words) {
            return Prediction(rule: .comma,
                              candidates: Self.ranked([",", ".", "?", "!", "\""]))
        }
        if Self.isQuoteIntroducer(words) {
            return Prediction(rule: .quote,
                              candidates: Self.ranked(["\"", ",", ".", "?", "!"]))
        }
        if Self.isExclamation(words) {
            return Prediction(rule: .exclamation,
                              candidates: Self.ranked(["!", ".", "?", ",", "\""]))
        }
        return Prediction(rule: .fallback,
                          candidates: Self.ranked([".", "?", "!", ",", "\""]))
    }

    /// Returns candidates ranked best-first for the text before the cursor.
    public func candidates(before context: String) -> [Candidate] {
        prediction(before: context).candidates
    }

    private static func isQuestion(_ words: [Substring]) -> Bool {
        guard let first = words.first else { return false }
        if whWords.contains(first) {
            // "when you land" is a subordinate clause, not a question --
            // "when" only asks when an auxiliary follows ("when do you land").
            if first == "when", words.count > 1, !auxiliaries.contains(words[1]),
               !imperativeCapableAuxiliaries.contains(words[1]) {
                // fall through to the other question checks
            } else {
                return true
            }
        }
        if auxiliaries.contains(first) { return true }
        if imperativeCapableAuxiliaries.contains(first), words.count > 1,
           pronouns.contains(words[1]) { return true }
        if requestVerbs.contains(first) { return true }
        if let last = words.last, words.count > 1 {
            if trailingTags.contains(last) { return true }
            // "call me for wat", "you did what"
            if whWords.contains(last) { return true }
        }
        if first == "you" || first == "u" {
            // "you good", "you in town", "you around later"
            if words.count <= 3, words.count > 1, checkInWords.contains(words[1]) { return true }
            // "you still stocked up", "u studying in sch"
            if words.count > 1, words[1] == "still" || words[1].hasSuffix("ing") {
                return true
            }
        }
        if first == "any" { return true }
        return false
    }

    private static func isQuoteIntroducer(_ words: [Substring]) -> Bool {
        guard let last = words.last else { return false }
        if sayVerbs.contains(last) { return true }
        // quote-forwarding idiom: "ever green quote ever told", "superb thought"
        if words.contains("quote") || words.contains("quotes") { return true }
        if last == "thought" || last == "thoughts" { return true }
        return false
    }

    private static func isCommaContinuation(_ words: [Substring]) -> Bool {
        guard let first = words.first else { return false }
        if subordinateOpeners.contains(first) { return true }
        if conjunctionOpeners.contains(first) { return true }
        if first == "even", words.count > 1, words[1] == "if" { return true }
        if first == "when", words.count > 1, !auxiliaries.contains(words[1]),
           !imperativeCapableAuxiliaries.contains(words[1]) { return true }
        // "good afternoon" usually continues with a name ("good afternoon, love")
        if first == "good", words.count > 1,
           ["morning", "afternoon", "evening", "night"].contains(String(words[1])) {
            return true
        }
        return false
    }

    private static func isExclamation(_ words: [Substring]) -> Bool {
        guard let first = words.first else { return false }
        if words.contains(where: { exclamationWords.contains($0) }) { return true }
        let joined = words.joined(separator: " ")
        if exclamationPhrases.contains(joined) { return true }
        if joined.hasPrefix("i cant wait") || joined.hasPrefix("cant wait") { return true }
        if thanksOpeners.contains(first) { return true }
        if greetingOpeners.contains(first), words.count <= 3 { return true }
        if first == "happy", words.count > 1, occasions.contains(words[1]) { return true }
        if first == "so", words.count > 1, emotionWords.contains(words[1]) { return true }
        if first == "lets", words.count > 1, words[1].hasPrefix("go") { return true }
        return false
    }

    /// The sentence being typed: text after the last terminal mark.
    private static func currentSentence(in context: String) -> Substring {
        context.split(omittingEmptySubsequences: false,
                      whereSeparator: { ".!?".contains($0) }).last ?? ""
    }

    /// Lowercased words with apostrophes stripped ("What's" -> "whats") so
    /// straight and curly forms hit the same sets; commas dropped from tokens.
    private static func tokens(_ segment: Substring) -> [Substring] {
        let normalized = segment.lowercased()
            .filter { $0 != "'" && $0 != "\u{2019}" && $0 != "," }
        return normalized[...].split(whereSeparator: { $0.isWhitespace })
    }
}
