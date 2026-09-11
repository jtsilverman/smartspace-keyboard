/// The seam between pure correction logic and the platform spell checker.
/// Tests supply a fake; Phase 3 wraps UITextChecker behind this so the
/// decision rules never import UIKit.
public protocol SpellChecking: Sendable {
    /// Ranked suggestions for a misspelled word, best first.
    /// Empty means the word is spelled correctly.
    func suggestions(for word: String) -> [String]

    /// Dictionary completions for a partial word ("keyb" -> keyboard...).
    /// Defaulted so suggestion-only checkers (and fakes) stay source-stable.
    func completions(for prefix: String) -> [String]
}

extension SpellChecking {
    public func completions(for prefix: String) -> [String] { [] }
}

/// What the keyboard should do with the word just committed.
public enum CorrectionDecision: Equatable, Sendable {
    case noChange
    case correct(to: String, alternatives: [String])
}

/// Decides whether the word just committed gets replaced with the checker's
/// top suggestion.
public struct CorrectionEngine: Sendable {
    private let checker: any SpellChecking
    private let contextModel: any ContextScoring
    private let lexicon: Set<String>

    /// Key widths. A tap must have sat this close to the candidate's key for a
    /// substitution to read as a thumb slip rather than a deliberate press.
    private static let slipReach: Double = 0.75

    /// What a split whose halves are a known word pair ("on my", "me later")
    /// costs against a one-edit word. Below 1: stock reads "onmy" as "on my"
    /// over "only" and "melater" as "me later" over "melter".
    private static let backedSplitCost: Double = 0.9
    /// What any other split costs. Above 1, so it wins only when no single
    /// word sits one edit away. Scoring every split below a substitution cost
    /// 8 points of the typo bench and took miscorrections from 17 to 41: the
    /// winners were "din net", "go ID" and "GT eat", and frequency cannot
    /// separate those from real splits ("din" scores 94 on the AOSP scale,
    /// "woke" 90). Whether the two words go together can, and that is the
    /// word-pair table.
    private static let splitCost: Double = 1.1
    /// Rank cutoff for a split half. Every split stock made in the recorded
    /// missed-space slice had both halves at 90 or better on the AOSP 0-255
    /// frequency scale, over 45 splits (EVAL.md); it refused "amin" rather
    /// than offer "am in". 20,308 words sit at or above that frequency, and
    /// the list is ordered by it.
    private static let commonEnough = 20_308

    /// - Parameter lexicon: protected words (contact names, text
    ///   replacements) that are never corrected away, matched
    ///   case-insensitively. Phase 3 fills this from UILexicon.
    /// The caller's lexicon (UILexicon: contacts, text replacements) unions
    /// with the shipped TextingLexicon; both are never-correct words.
    /// - Parameter contextModel: what the words already typed say about
    ///   each candidate. The word-pair table by default.
    public init(checker: any SpellChecking, lexicon: Set<String> = [],
                contextModel: any ContextScoring = WordPairModel()) {
        self.checker = checker
        self.contextModel = contextModel
        self.lexicon = TextingLexicon.words.union(lexicon.map { $0.lowercased() })
    }

    /// - Parameter session: undo memory; a word the user has un-corrected
    ///   in this session is never corrected again.
    /// - Parameter touches: where the thumb landed for each letter of the
    ///   word being committed. Nil on every path that has no touch history,
    ///   which is every caller until KeyTouchSurface records one.
    public func decision(
        for context: String,
        touches: TouchTrail? = nil,
        session: CorrectionSession = CorrectionSession()
    ) -> CorrectionDecision {
        guard let word = WordBoundary.lastWord(in: context) else { return .noChange }
        guard !lexicon.contains(word.lowercased()) else { return .noChange }
        guard !session.isProtected(word) else { return .noChange }
        // A capitalized word mid-sentence is a proper noun (names, brands,
        // Professor Cant); its capital came from the user, not autocap, so
        // no rewrite of any kind -- contraction fixes included. At a
        // sentence start the capital IS autocap and typos still fix.
        // Sentence start here includes any trailing period ("Ave. Dont"):
        // a smart-space period after an abbreviation deliberately ended
        // the sentence even though CapitalizationRule reads it as one.
        let prefix = String(context.dropLast(word.count))
        let sentenceStart = CapitalizationRule.shouldCapitalize(before: prefix)
            || prefix.last(where: { !$0.isWhitespace }).map { ".!?".contains($0) } == true
        if word.first?.isUppercase == true, word.dropFirst().contains(where: \.isLowercase),
           !sentenceStart {
            return .noChange
        }
        // Curated contraction fixes are deterministic and outrank the
        // checker AND the acronym guard (DONT is a shouted contraction,
        // not an acronym). Only when the fix actually differs -- a phantom
        // I -> I correction would put an undo slot in the bar that, tapped,
        // protects "i" and kills the fix for the session.
        if let fixed = ContractionRule.transform(word), fixed != word {
            return .correct(to: fixed, alternatives: [])
        }
        // "Ill"/"Id" at a sentence start are the autocap products of typing
        // an I-contraction (ill be there -> Ill); lowercase and mid-sentence
        // forms keep the homograph protection above and in ContractionRule.
        if let fixed = ["Ill": "I\u{2019}ll", "Id": "I\u{2019}d"][word] {
            return .correct(to: fixed, alternatives: [])
        }
        // Calendar names typed lowercase capitalize (coming saturday ->
        // Saturday); curated list, march/may homographs excluded.
        if let fixed = CalendarRule.transform(word) {
            return .correct(to: fixed, alternatives: [])
        }
        // All-caps words are acronyms more often than typos; correcting
        // them mangles deliberate input.
        let letters = word.filter(\.isLetter)
        if letters.count >= 2, letters.allSatisfy(\.isUppercase) { return .noChange }
        // Two-letter tokens are texting shortforms (gn, rn, ty, np) and
        // letter runs of 3+ are deliberate elongation (sooo, plsss); the
        // checker's guesses for both mangle intended text.
        if word.count <= 2 { return .noChange }
        if hasLetterRun(word, of: 3) { return .noChange }
        var suggestions = checker.suggestions(for: word)
            .filter { !$0.contains(" ") || takesSplit(halves(of: $0)) }
            .map { recased($0, like: word) }
        // Most committed words are spelled right and the list is empty; the
        // walk back through the text for the word before is only paid when
        // there is something to rank.
        guard !suggestions.isEmpty else { return .noChange }
        // Re-rank by edit distance, then by the word before (more thn -> than,
        // and thn -> then), then English word frequency, then the checker's
        // own order as the deterministic last tiebreak. The order a checker
        // hands up is not trusted: UITextChecker returned its guesses
        // alphabetically, and DictionarySpellChecker's scan is capped at eight.
        // A sentence start has no word before it: the last word of the
        // previous sentence says nothing about this one.
        let previous = sentenceStart ? []
            : WordBoundary.lastWord(in: prefix.trimmingCharacters(in: .whitespaces)).map { [$0] } ?? []
        let lower = word.lowercased()
        suggestions = suggestions.enumerated()
            .map { (index: $0.offset, text: $0.element,
                    distance: typoDistance(from: lower, to: $0.element.lowercased()),
                    likelihood: contextModel.likelihood(of: halves(of: $0.element)[0], after: previous),
                    rank: WordRank.rank($0.element)) }
            .sorted {
                if $0.distance != $1.distance { return $0.distance < $1.distance }
                if $0.likelihood != $1.likelihood { return $0.likelihood ?? 0 > $1.likelihood ?? 0 }
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                return $0.index < $1.index
            }
            .map(\.text)
        // A suggestion that is the typed word merely recased (jake -> Jake)
        // IS the word; it outranks any letter-changing suggestion.
        if let i = suggestions.firstIndex(where: { $0.lowercased() == word.lowercased() }),
           i > 0 {
            suggestions.insert(suggestions.remove(at: i), at: 0)
        }
        guard let top = suggestions.first else { return .noChange }
        // Swapping one name for another is the most expensive miscorrection
        // there is, and a bigger dictionary makes it likelier: it knows more
        // names one edit apart. The stock oracle recorded stock refusing the
        // same move -- michal stayed Michal, jesica stayed Jesica. So a
        // capitalized word the list does not know keeps its spelling when the
        // best candidate is itself a proper noun. The dictionary's own casing
        // decides that, never the recased output: "Teh" -> "The" is a common
        // word wearing an autocap, and it still corrects.
        // Where the thumb landed outranks every letter-level guess about it.
        // A substitution is a slip only when the tap sat closer to the
        // candidate's key than this, in key widths: a tap on the boundary
        // between two keys is 0.7 from each, and a dead-centre tap is a full
        // key width from its nearest neighbour and 1.41 from a diagonal one.
        // Stock recovered 100% of off-centre wrong letters and 47% of
        // dead-centre ones (EVAL.md, 2026-08-20).
        if let touches, touches.count == word.count,
           let slip = KeyNeighbors.singleSubstitution(word.lowercased(),
                                                      top.lowercased()),
           let reach = touches.distance(at: slip.index, to: slip.meant),
           reach > Self.slipReach {
            return .noChange
        }
        if word.first?.isUppercase == true, !WordRank.isKnown(word) {
            if WordRank.isProperNoun(top) { return .noChange }
            // A far-key swap is not a thumb slip. Kylian -> Kalian trades y
            // for a, which sit at opposite ends of the keyboard, so the word
            // was meant as typed.
            if let slip = KeyNeighbors.singleSubstitution(word.lowercased(),
                                                          top.lowercased()),
               !KeyNeighbors.areAdjacent(slip.typed, slip.meant) {
                return .noChange
            }
        }
        // A top suggestion far from the typed word is the checker guessing
        // at a word it doesn't know (names, slang, loanwords) -- rejecting
        // it beats mangling. Damerau (transposition = 1 edit), so wierd ->
        // weird stays a near fix.
        guard EditDistance.damerau(word.lowercased(), top.lowercased())
                <= max(1, word.count / 4) else { return .noChange }
        return .correct(to: top, alternatives: Array(suggestions.dropFirst()))
    }

    /// Edit distance with one typo-shape refinement: a candidate that only
    /// restores a dropped double letter (realy -> really) is closer than a
    /// generic single edit (realy -> real), because dropping one of a
    /// doubled pair is the more common slip.
    private func typoDistance(from word: String, to candidate: String) -> Double {
        // A candidate carrying a space is a missed-space split, and it keeps
        // every letter the thumb typed.
        if candidate.contains(" ") { return splitCost(of: candidate) }
        let base = Double(EditDistance.damerau(word, candidate))
        guard base == 1 else { return base }
        if restoresDoubledLetter(word: word, candidate: candidate) { return 0.5 }
        // A mistyped letter is usually the key next to the one meant, so a
        // swap for a far key ranks behind every other single edit. Neighbour
        // swaps stay level with the rest: word frequency decides between
        // them, and a shape bonus there buried the common word under a rare
        // one (teh offered eth ahead of ten).
        guard let slip = KeyNeighbors.singleSubstitution(word, candidate),
              !KeyNeighbors.areAdjacent(slip.typed, slip.meant) else { return base }
        return 1.5
    }

    /// True when the halves are a pair the context model has evidence for.
    private func isPair(_ halves: [String]) -> Bool {
        contextModel.likelihood(of: halves[1], after: [halves[0]]) != nil
    }

    /// A split's cost turns on whether its halves go together.
    private func splitCost(of candidate: String) -> Double {
        isPair(halves(of: candidate)) ? Self.backedSplitCost : Self.splitCost
    }

    /// Which splits are candidates at all. Both halves common, because stock
    /// refused "amin" for "am in". Neither half a proper noun: "Kaius" became
    /// "Kai us", a protection row. And a split of two short words only when
    /// they are a pair: that shape produced "bad ass" for "badass", "din net"
    /// for "dinnet" and "go ID" for "goid", and "badass" is a protection row
    /// the word list does not know.
    private func takesSplit(_ halves: [String]) -> Bool {
        guard halves.allSatisfy({ WordRank.rank($0) <= Self.commonEnough }),
              !halves.contains(where: WordRank.isProperNoun) else { return false }
        return halves.contains(where: { $0.count >= 4 }) || isPair(halves)
    }

    /// True when removing one of a doubled pair in the candidate yields the
    /// typed word exactly.
    private func restoresDoubledLetter(word: String, candidate: String) -> Bool {
        guard candidate.count == word.count + 1 else { return false }
        let c = Array(candidate)
        for i in 1..<c.count where c[i] == c[i - 1] {
            var trimmed = c
            trimmed.remove(at: i)
            if String(trimmed) == word { return true }
        }
        return false
    }

    /// A candidate's words. One for a dictionary word, two for a split
    /// ("on my"); the first is what follows the text before the candidate.
    private func halves(of candidate: String) -> [String] {
        candidate.split(separator: " ").map(String.init)
    }

    private func hasLetterRun(_ word: String, of length: Int) -> Bool {
        var run = 1
        var prev: Character?
        for ch in word.lowercased() {
            run = (ch == prev) ? run + 1 : 1
            if run >= length { return true }
            prev = ch
        }
        return false
    }

    /// A word typed with a leading capital keeps it through the correction.
    /// A suggestion carrying any capital of its own (iPhone, McDonald's)
    /// already knows its casing and is passed through untouched.
    private func recased(_ suggestion: String, like word: String) -> String {
        guard word.first?.isUppercase == true,
              !suggestion.contains(where: \.isUppercase),
              let first = suggestion.first else {
            return suggestion
        }
        return first.uppercased() + suggestion.dropFirst()
    }
}
