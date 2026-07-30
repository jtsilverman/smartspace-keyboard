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

    /// The abbreviations that are titles: a proper name follows ("Mr.
    /// Smith", "St. Louis"), so the next word capitalizes even though the
    /// sentence continues.
    private static let titleAbbreviations: Set<Substring> = [
        "mr", "mrs", "ms", "dr", "prof", "st"
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

    /// Vocative openers: greeting + addressee continues with a comma
    /// ("hey mom,"). A verb after the greeting means a message, not an address.
    private static let vocativeOpeners: Set<Substring> = [
        "hey", "yo", "hi", "hello", "sup", "psst"
    ]
    private static let vocativeVerbBlacklist: Set<Substring> = [
        "come", "call", "text", "listen", "wait", "stop", "look", "check",
        "send", "tell", "get", "go", "pick", "grab", "watch", "answer", "hurry"
    ]

    /// Meta-discourse heads: a short verbless NP ending in one of these sets
    /// up the message ("quick thing,", "big news,").
    private static let discourseNouns: Set<Substring> = [
        "thing", "question", "favor", "ask", "update", "news", "note",
        "problem", "idea", "story", "storytime", "fact", "reminder", "q",
        "secret", "confession", "rant"
    ]

    /// Lead-in idiom tails ("just so you know,", "for what it's worth,").
    private static let leadInTails: Set<Substring> = ["know", "forget", "worth"]

    /// Two-word contrast/summary fragments ("best part,", "only catch,").
    private static let contrastTailNouns: Set<Substring> = [
        "side", "part", "catch", "lining", "upside", "downside", "bonus"
    ]

    /// Fronted contrastive/summative adverbial idioms -- a bounded English
    /// idiom class, prefix-matched so trailing words don't break them.
    private static let idiomPrefixes: [String] = [
        "then again", "even so", "even then", "that said", "that being said",
        "jokes aside", "long story short", "truth be told",
        "one way or another", "worst comes to worst", "if nothing else",
        "all things considered", "at the end of the day",
        "as luck would have it", "for better or worse", "at the same time",
        "by the same token", "come to think of it", "not gonna lie",
        "now that", "real talk", "first things first", "first off",
        "first of all", "on the other hand"
    ]

    /// Single-token discourse markers that always lead in ("ngl,", "fyi,").
    private static let singleDiscourseMarkers: Set<Substring> = [
        "ngl", "fyi", "btw", "psst", "listen", "storytime", "anyway",
        "anyways", "tbh"
    ]

    /// Urgency markers that turn a short imperative into a burst
    /// ("call me right now", "text back asap").
    private static let urgencyMarkers: Set<Substring> = [
        "now", "rn", "asap", "immediately", "hurry"
    ]

    /// One-breath hazard interjections ("duck", "incoming").
    private static let hazardBursts: Set<Substring> = [
        "duck", "run", "incoming", "brakes", "hide"
    ]

    /// Verbs of speech/inscription that introduce a quotation when they end
    /// the sentence ("she said", "the sign reads", "my aunt texted"). A
    /// bounded linguistic class (say-verbs, manner-of-speaking, inscription),
    /// not a corpus harvest.
    private static let sayVerbs: Set<Substring> = [
        "say", "says", "said", "saying", "goes", "went", "replied", "replies",
        "texted", "wrote", "writes", "reads", "announced", "yelled",
        "whispered", "shouted", "muttered", "screamed", "hissed", "chanted",
        "mumbled", "blurted", "declared", "stated", "states", "exclaimed",
        "admitted", "asked", "insisted", "captioned"
    ]

    /// Subjects that make final "goes/went" motion or outcome, never speech
    /// ("guess how it went").
    private static let nonSpeechGoSubjects: Set<Substring> = ["it", "this", "that"]

    /// BE-forms and quotative particles: "was like", "is all", "were just like".
    private static let beForms: Set<Substring> = ["was", "were", "is", "are", "r", "am"]
    private static let quotativeParticles: Set<Substring> = ["like", "all"]

    /// Communication-artifact nouns: as the subject of BE they promise a
    /// quotation ("his exact words were"); followed by a preposition they head
    /// a bare-NP introducer ("note on the windshield", "text from dad").
    private static let commNouns: Set<Substring> = [
        "words", "reply", "response", "message", "text", "line", "caption",
        "answer", "quote", "note", "sign", "voicemail", "email", "error",
        "banner", "sticker", "headline", "graffiti", "plaque", "memo",
        "subject", "title", "motto", "slogan", "tagline", "sentence", "verse",
        "lyrics", "bio", "speech"
    ]

    /// Manner-of-speaking verb stems, matched after stripping -s/-ed/-ing so
    /// every inflection introduces a quote ("kept squawking", "sings").
    private static let mannerVerbStems: Set<Substring> = [
        "sing", "squawk", "scream", "chant", "holler", "repeat", "mumble",
        "whisper", "yell", "shout", "mutter", "hiss", "blurt"
    ]

    /// Hype adjectives that exclaim when predicated with BE ("that dunk was
    /// bonkers"); bare "wild"/"nuts" mid-sentence stays neutral.
    private static let hypeAdjectives: Set<Substring> = [
        "unreal", "filthy", "wild", "nuts", "bonkers", "elite", "immaculate",
        "flawless", "legendary", "perfection"
    ]

    /// One-breath body-reaction bursts ("goosebumps", "chills literally chills").
    private static let bodyReactionBursts: Set<Substring> = ["goosebumps", "chills"]

    /// Superlative detection: -est words minus common false friends.
    private static let superlativeStopList: Set<Substring> = [
        "west", "rest", "test", "guest", "chest", "vest", "nest", "pest",
        "honest", "modest", "forest", "interest", "protest", "harvest",
        "earnest", "latest"
    ]

    /// Scope windows that turn a superlative into a burst ("best news all
    /// week", "loudest crowd ever").
    private static let scopeWindows: Set<Substring> = [
        "ever", "week", "year", "day", "life", "town", "earth", "time", "history"
    ]

    /// Second-person praise verbs ("you nailed it", "u crushed that set").
    private static let praiseVerbs: Set<Substring> = [
        "crushed", "killed", "nailed", "aced", "smashed"
    ]
    private static let npPrepositions: Set<Substring> = [
        "on", "from", "in", "at", "over", "under", "by"
    ]

    /// Rank orders per prediction shape; comma and quote never end a sentence.
    private static func ranked(_ order: [String]) -> [Candidate] {
        order.map { text in
            Candidate(text: text, endsSentence: text != "," && text != "\"")
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

    /// Whether the token is a title abbreviation ("Mr.", "st") -- a proper
    /// name follows, so the capitalization rule capitalizes the next word.
    public static func isTitleAbbreviation(_ rawToken: String) -> Bool {
        var token = rawToken.lowercased()
        if token.hasSuffix(".") { token.removeLast() }
        return Self.titleAbbreviations.contains(token[...])
    }

    /// Returns the ranked candidates plus which rule produced them -- the
    /// label outcome records key on for stats and personal re-ranking.
    public func prediction(before context: String) -> Prediction {
        let rawLastToken = context.lowercased()
            .split(whereSeparator: { $0.isWhitespace }).last.map(String.init) ?? ""
        // Double-space is the end-my-sentence gesture, so even an
        // abbreviation's period ends the sentence here -- the abbreviation
        // rules keep only their period-first ranking (v4 e2e invariant).
        if Self.dottedAbbreviations.contains(rawLastToken) {
            return Prediction(rule: .dottedAbbreviation,
                              candidates: Self.ranked([".", "?", "!", ",", "\""]))
        }

        let sentence = Self.currentSentence(in: context)
        let words = Self.tokens(sentence)
        if words.isEmpty, context.contains(where: { !$0.isWhitespace }) {
            return Prediction(rule: .terminalGuard, candidates: [])
        }
        if let last = words.last, Self.abbreviations.contains(last) {
            return Prediction(rule: .abbreviation,
                              candidates: Self.ranked([".", "?", "!", ",", "\""]))
        }

        // A question can hide in the last comma-separated clause
        // ("just got home babe, are you still awake") or behind a greeting
        // opener ("hey are we still on").
        let clauseWords = Self.tokens(sentence.split(separator: ",").last ?? sentence)
        var greetingStripped = words
        if let first = greetingStripped.first,
           Self.greetingOpeners.contains(first) || ["yo", "ok", "okay"].contains(first) {
            greetingStripped.removeFirst()
        }
        if Self.isQuestion(words) || Self.isQuestion(clauseWords)
            || Self.isQuestion(greetingStripped) {
            return Prediction(rule: .question,
                              candidates: Self.ranked(["?", ".", "!", ",", "\""]))
        }
        // A fully shouted sentence exclaims (WE WON) -- checked on the raw
        // sentence because tokens() lowercases. Short single tokens (OK)
        // are ordinary caps, not shouting.
        let rawLetters = sentence.filter(\.isLetter)
        if !rawLetters.isEmpty, rawLetters.allSatisfy(\.isUppercase),
           words.count >= 2 || rawLetters.count >= 4 {
            return Prediction(rule: .exclamation,
                              candidates: Self.ranked(["!", ".", "?", ",", "\""]))
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
        // First-person completion statements ("i finally...", "we just...")
        // stay period-first but rank ! second: excited news recovers in one
        // cycle tap. Same .fallback label -- ordering tweak, not a new rule.
        if let first = words.first, ["i", "we", "im", "my"].contains(first),
           words.contains("finally") || words.contains("just") {
            return Prediction(rule: .fallback,
                              candidates: Self.ranked([".", "!", "?", ",", "\""]))
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
        // Exclamative syntax, not a question: "what a game", "what an arm".
        if first == "what" || first == "whats", words.count > 1,
           words[1] == "a" || words[1] == "an" { return false }
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
        let prev = words.count > 1 ? words[words.count - 2] : nil
        if sayVerbs.contains(last) {
            // "guess how it went": outcome, not speech.
            if last == "goes" || last == "went",
               let prev, nonSpeechGoSubjects.contains(prev) { return false }
            return true
        }
        // "the plumber was like", "my niece is all", "they were just like"
        // (one optional adverb may sit between BE and the particle).
        if quotativeParticles.contains(last), let prev {
            if beForms.contains(prev) { return true }
            if ["just", "literally", "basically"].contains(prev), words.count > 2,
               beForms.contains(words[words.count - 3]) { return true }
        }
        // "his exact words were", "the subject line is"
        if beForms.contains(last), let prev, commNouns.contains(prev) {
            return true
        }
        // Bare-NP introducer: a comm-artifact noun directly followed by a
        // preposition ("note on the windshield") -- an imperative would take
        // an object instead ("text me", "sign the slip").
        if words.count <= 6 {
            for i in words.indices.dropLast() where
                commNouns.contains(words[i]) && npPrepositions.contains(words[i + 1]) {
                return true
            }
        }
        // Any inflection of a manner-of-speaking verb in final position
        // ("kept squawking", "the jukebox started singing").
        if mannerVerbStems.contains(stem(last)) { return true }
        // Dangling introducer tails: "opens with", "pop up again with" --
        // never gerund objects ("what im dealing with") or "come/put up with".
        if last == "with", words.count <= 6, let prev,
           !prev.hasSuffix("ing"), prev != "come", prev != "up" { return true }
        if last == "just", words.count >= 3, let first = words.first,
           !pronouns.contains(first) { return true }
        // Final BE with a communication noun anywhere as subject head:
        // "the last verse of the song is".
        if beForms.contains(last), words.contains(where: { commNouns.contains($0) }) {
            return true
        }
        if words.contains("verbatim") { return true }
        // quote-forwarding idiom: "ever green quote ever told", "superb thought"
        if words.contains("quote") || words.contains("quotes") { return true }
        if last == "thought" || last == "thoughts" { return true }
        return false
    }

    /// Crude inflection strip for closed verb-class checks: -ing / -ed / -s.
    private static func stem(_ word: Substring) -> Substring {
        if word.hasSuffix("ing") { return word.dropLast(3) }
        if word.hasSuffix("ed") { return word.dropLast(2) }
        if word.hasSuffix("s") { return word.dropLast(1) }
        return word
    }

    private static func isCommaContinuation(_ words: [Substring]) -> Bool {
        guard let first = words.first else { return false }
        if subordinateOpeners.contains(first) { return true }
        if conjunctionOpeners.contains(first) { return true }
        if first == "even", words.count > 1,
           ["if", "tho", "though", "so", "then"].contains(String(words[1])) { return true }
        if first == "when", words.count > 1, !auxiliaries.contains(words[1]),
           !imperativeCapableAuxiliaries.contains(words[1]) { return true }
        // "good afternoon" usually continues with a name ("good afternoon, love")
        if first == "good", words.count > 1,
           ["morning", "afternoon", "evening", "night"].contains(String(words[1])) {
            return true
        }
        // Vocative: greeting + addressee ("hey mom"), never greeting + verb
        // ("hey call me back") or doubled greeting ("hey hey").
        if vocativeOpeners.contains(first), (2...3).contains(words.count),
           !vocativeOpeners.contains(words[1]), !greetingOpeners.contains(words[1]),
           !vocativeVerbBlacklist.contains(words[1]),
           words[1] != "there" {  // "hey there" is a complete greeting
            return true
        }
        // Meta-discourse lead-in: short verbless NP ("quick thing", "big news").
        if let last = words.last, words.count <= 4, discourseNouns.contains(last) {
            return true
        }
        // Lead-in idiom tails: "just so u know", "for what its worth".
        if let last = words.last, words.count <= 5, leadInTails.contains(last) {
            return true
        }
        // Two-word contrast/summary fragments: "best part", "only catch".
        if let last = words.last, words.count <= 2, contrastTailNouns.contains(last) {
            return true
        }
        // "on the flip side", "on the other hand"
        if first == "on", words.count > 1, words[1] == "the",
           let last = words.last, ["side", "hand", "token"].contains(String(last)) {
            return true
        }
        // Fronted evaluative to-infinitives only: "to be fair", "to start",
        // "to make matters worse" -- not arbitrary "to X" phrases.
        if first == "to", words.count <= 4, words.count > 1,
           ["be", "start", "sum", "recap", "clarify", "make", "top"].contains(String(words[1])) {
            return true
        }
        // Trailing concession: "for real tho", "still though", "memes aside".
        if let last = words.last, words.count <= 3,
           last == "tho" || last == "though" || last == "aside" { return true }
        if singleDiscourseMarkers.contains(first), words.count <= 2 { return true }
        if first == "attention", words.count <= 3 { return true }
        if ["ok", "okay"].contains(String(first)), words.count <= 3, words.count > 1 { return true }
        if first == "so", words.count > 1, words[1] == "about" { return true }
        let joined = words.joined(separator: " ")
        for prefix in idiomPrefixes where joined.hasPrefix(prefix) { return true }
        return false
    }

    private static func isExclamation(_ words: [Substring]) -> Bool {
        guard let first = words.first else { return false }
        if words.contains(where: { exclamationWords.contains($0) }) { return true }
        let joined = words.joined(separator: " ")
        if exclamationPhrases.contains(joined) { return true }
        for prefix in ["i cant wait", "cant wait", "no way", "no shot",
                       "i cant believe", "cant believe", "i cant stop", "cant stop"]
        where joined.hasPrefix(prefix) { return true }
        if thanksOpeners.contains(first) { return true }
        if greetingOpeners.contains(first), words.count <= 3 { return true }
        // Occasion wishes exclaim regardless of which occasion follows.
        if first == "happy" || first == "merry" || first == "welcome",
           words.count > 1 { return true }
        // "so <emotion>" with up to two intensifiers between ("so stinkin proud").
        if first == "so", words.count > 1,
           words.prefix(4).dropFirst().contains(where: { emotionWords.contains($0) }) {
            return true
        }
        if first == "lets", words.count > 1, words[1].hasPrefix("go") { return true }
        // Exclamative syntax: "what a comeback", "such a gorgeous view".
        if (first == "what" || first == "whats" || first == "such"), words.count > 1,
           words[1] == "a" || words[1] == "an" { return true }
        // Superlative + scope window: "best news all week", "loudest crowd ever".
        let hasSuperlative = words.contains {
            $0 == "best" || $0 == "worst" ||
            ($0.hasSuffix("est") && $0.count > 4 && !superlativeStopList.contains($0))
        }
        if hasSuperlative, words.contains(where: { scopeWindows.contains($0) }) {
            return true
        }
        // Second-person praise: "you nailed the interview".
        if first == "you" || first == "u" || first == "ya",
           words.contains(where: { praiseVerbs.contains($0) }) { return true }
        // Hype adjective predicated with BE: "that dunk was bonkers".
        for i in words.indices.dropFirst() where hypeAdjectives.contains(words[i]) {
            if beForms.contains(words[i - 1]) || words[i - 1] == "looks" { return true }
        }
        if words.count <= 3, words.contains(where: { bodyReactionBursts.contains($0) }) {
            return true
        }
        // Urgent imperative: short command with the urgency marker in command
        // position (final, or right after the verb: "leave now or..."). A BE
        // form anywhere means a statement ("mom is home now"), not a command.
        let hasUrgency = (words.last.map { urgencyMarkers.contains($0) } ?? false)
            || (words.count > 1 && urgencyMarkers.contains(words[1]))
            || first == "now" || first == "hurry"
        if words.count <= 5, hasUrgency,
           !words.contains(where: { beForms.contains($0) }),
           !pronouns.contains(first), !["the", "a", "my", "ur", "your", "im"].contains(String(first)),
           !first.hasSuffix("ing") {
            return true
        }
        // Hazard interjections: one-breath only ("duck"), plus fixed warnings.
        if words.count == 1, hazardBursts.contains(first) { return true }
        for prefix in ["watch out", "heads up", "hurry up"] where joined.hasPrefix(prefix) {
            return true
        }
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
