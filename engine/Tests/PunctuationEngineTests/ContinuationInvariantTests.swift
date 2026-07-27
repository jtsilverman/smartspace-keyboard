import Testing
import PunctuationEngine

// Invariants 3-5 of the rules-invariants spec: vocative/lead-in commas,
// fronted contrastive/summative idiom commas, and urgent imperatives.
// Novel sentences only; assertNovel proves none is a corpus row.

private func assertNovel(_ text: String) {
    let benchmarkTexts = (blindCorpusDev + blindCorpusTest + realV3Dev + realV3Test).map(\.text)
        + corpus.map(\.text)
    #expect(!benchmarkTexts.contains(text), "test sentence duplicates a corpus row: \(text)")
}

private func topMark(_ text: String) -> String? {
    PunctuationEngine().candidates(before: text).first?.text
}

// MARK: - Invariant 3: vocative / lead-in commas

@Test func greetingPlusAddresseeContinuesWithComma() {
    for text in ["hey coach", "yo captain", "hello ladies"] {
        assertNovel(text)
        #expect(topMark(text) == ",", "expected comma for: \(text)")
    }
}

@Test func metaDiscourseLeadInContinuesWithComma() {
    for text in ["dumb question", "tiny favor", "huge news", "unrelated thought maybe"] {
        assertNovel(text)
        #expect(topMark(text) == ",", "expected comma for: \(text)")
    }
}

@Test func leadInIdiomTailsContinueWithComma() {
    for text in ["just so u know", "before i forget again", "for whatever its worth"] {
        assertNovel(text)
        #expect(topMark(text) == ",", "expected comma for: \(text)")
    }
}

@Test func vocativeGuardsHold() {
    // greeting + verb is a message, not an address
    for text in ["hey call me back", "yo check the score"] {
        assertNovel(text)
        #expect(topMark(text) != ",", "greeting+verb misread as vocative: \(text)")
    }
}

// MARK: - Invariant 4: fronted contrastive/summative idioms

@Test func contrastiveIdiomsContinueWithComma() {
    for text in [
        "then again maybe not", "jokes aside", "for real tho",
        "on the bright side", "best part", "to be perfectly fair",
        "now that i think about it more",
    ] {
        assertNovel(text)
        #expect(topMark(text) == ",", "expected comma for: \(text)")
    }
}

// MARK: - Invariant 5: urgent imperatives

@Test func urgencyMarkedImperativesExclaim() {
    for text in ["call the vet right now", "grab ur bag asap", "keys now"] {
        assertNovel(text)
        #expect(topMark(text) == "!", "expected ! for: \(text)")
    }
}

@Test func hazardInterjectionsExclaim() {
    for text in ["duck", "watch out behind u", "hurry up"] {
        assertNovel(text)
        #expect(topMark(text) == "!", "expected ! for: \(text)")
    }
}

@Test func calmImperativesStayPeriod() {
    for text in ["water the ferns while im gone", "watch the finale without me tonight"] {
        assertNovel(text)
        #expect(topMark(text) == ".", "calm imperative should stay period: \(text)")
    }
}
