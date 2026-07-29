import Testing
import PunctuationEngine

/// Prediction invariants surfaced by the v4 e2e scenario dev misses.
/// Each names a class, never a row.

private let engine = PunctuationEngine()

@Suite struct GreetingPrefixedQuestions {
    /// Texting questions routinely open with a greeting ("hey are we still
    /// on"); the aux-inversion behind the greeting still asks.
    @Test(arguments: [
        "hey are we still on for tomorrow",
        "hi do you have the keys",
        "yo what time does it start",
        "ok can you send it",
    ])
    func greetingThenAuxAsks(context: String) {
        #expect(engine.prediction(before: context).candidates.first?.text == "?")
    }

    /// Greeting + addressee stays a vocative comma; greeting + verb stays
    /// non-question.
    @Test func vocativeAndImperativeUnchanged() {
        #expect(engine.prediction(before: "hey mom").candidates.first?.text == ",")
        #expect(engine.prediction(before: "hey call me back").candidates.first?.text != "?")
    }
}

@Suite struct AllCapsExclamation {
    /// A shouted sentence (every letter uppercase) exclaims: WE WON! The
    /// lowercasing tokenizer must not eat the signal.
    @Test(arguments: ["WE WON", "STOP", "THIS IS AMAZING", "LFG BOYS"])
    func shoutingExclaims(context: String) {
        #expect(engine.prediction(before: context).candidates.first?.text == "!")
    }

    /// Short acronym-ish tokens are not shouting; mixed case is not
    /// shouting; caps questions still ask.
    @Test func nonShoutsUnchanged() {
        #expect(engine.prediction(before: "OK").candidates.first?.text != "!")
        #expect(engine.prediction(before: "We won").candidates.first?.text == ".")
        #expect(engine.prediction(before: "ARE YOU SERIOUS").candidates.first?.text == "?")
    }
}

@Suite struct SmartPeriodAlwaysTerminal {
    /// Double-space is the end-my-sentence gesture; the period it inserts
    /// ends the sentence even after an abbreviation ("5th Ave" -> next word
    /// capitalizes). The abbreviation rules keep their period-first ranking.
    @Test func abbreviationPeriodEndsSentence() {
        let p = engine.prediction(before: "the place is on 5th ave")
        #expect(p.rule == .abbreviation)
        #expect(p.candidates.first == Candidate(text: ".", endsSentence: true))
    }

    @Test func dottedAbbreviationPeriodEndsSentence() {
        let p = engine.prediction(before: "loved it e.g")
        #expect(p.rule == .dottedAbbreviation)
        #expect(p.candidates.first == Candidate(text: ".", endsSentence: true))
    }
}
