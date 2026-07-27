import Testing
import PunctuationEngine

// Invariant: a clause that ENDS in a communication/inscription verb (or the
// BE+like idiom, or "<comm-noun> was/were"), or a bare noun phrase built on a
// communication artifact ("note on the windshield"), introduces a quotation.
// Tests use NOVEL sentences: assertNovel proves none is a corpus row, so a
// pass can never come from fitting the benchmark.

private func assertNovel(_ text: String) {
    let benchmarkTexts = (blindCorpusDev + blindCorpusTest + realV3Dev + realV3Test).map(\.text)
        + corpus.map(\.text)
    #expect(!benchmarkTexts.contains(text), "test sentence duplicates a corpus row: \(text)")
}

private func topMark(_ text: String) -> String? {
    PunctuationEngine().candidates(before: text).first?.text
}

@Test func finalCommunicationVerbIntroducesQuote() {
    for text in [
        "the billboard downtown says",
        "my aunt texted",
        "the umpire turned around and yelled",
        "her doctor finally admitted",
        "the librarian whispered",
    ] {
        assertNovel(text)
        #expect(topMark(text) == "\"", "expected quote for: \(text)")
    }
}

@Test func beLikeIdiomIntroducesQuote() {
    for text in [
        "the plumber was like",
        "my niece is all",
        "they were just like",
    ] {
        assertNovel(text)
        #expect(topMark(text) == "\"", "expected quote for: \(text)")
    }
}

@Test func commNounPlusBeIntroducesQuote() {
    for text in [
        "his exact words were",
        "her whole response was",
        "the subject line is",
    ] {
        assertNovel(text)
        #expect(topMark(text) == "\"", "expected quote for: \(text)")
    }
}

@Test func communicationArtifactNounPhraseIntroducesQuote() {
    for text in [
        "note on the windshield",
        "banner over the entrance",
        "voicemail from my dentist",
    ] {
        assertNovel(text)
        #expect(topMark(text) == "\"", "expected quote for: \(text)")
    }
}

@Test func quoteGuardsRejectNonIntroducers() {
    // "went/goes" after it/this/that is motion or outcome, not speech.
    let outcome = "guess how it went"
    assertNovel(outcome)
    #expect(topMark(outcome) != "\"")
    // Imperatives that start with a comm-artifact word are commands, not NPs.
    for text in ["text me when your flight lands", "sign the permission slip tonight"] {
        assertNovel(text)
        #expect(topMark(text) != "\"", "imperative misread as quote: \(text)")
    }
}
