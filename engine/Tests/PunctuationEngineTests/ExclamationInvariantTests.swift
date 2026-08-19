import Testing
import PunctuationEngine

// Invariant: exclamation is signaled by STRUCTURE, not a fixed cheer-word
// list -- exclamative syntax ("what a X", "such a X"), superlative + scope
// window ("best X ever/in town"), second-person praise ("you nailed it"),
// hype adjectives after BE, conventional burst prefixes ("no shot",
// "cant believe", "cant stop"), and occasion wishes ("happy X", "welcome Y").
// First-person completion statements ("i finally...") rank ! second: the
// semantic remainder is the ML lane, top-2 covers it.

private func assertNovel(_ text: String) {
    let benchmarkTexts = (blindCorpusDev + blindCorpusTest + realV3Dev + realV3Test).map(\.text)
        + corpus.map(\.text)
    #expect(!benchmarkTexts.contains(text), "test sentence duplicates a corpus row: \(text)")
}

private func marks(_ text: String) -> [String] {
    PunctuationEngine().candidates(before: text).map(\.text)
}

@Test func exclamativeSyntaxOutranksQuestion() {
    for text in ["what a weekend that was", "what an arm on that kid", "such a gorgeous view"] {
        assertNovel(text)
        #expect(marks(text).first == "!", "expected ! for: \(text)")
    }
}

@Test func superlativeWithScopeWindowExclaims() {
    for text in ["cleanest set ever", "best coffee in town", "worst traffic of my life"] {
        assertNovel(text)
        #expect(marks(text).first == "!", "expected ! for: \(text)")
    }
}

@Test func secondPersonPraiseExclaims() {
    for text in ["you nailed the interview", "u smashed that solo"] {
        assertNovel(text)
        #expect(marks(text).first == "!", "expected ! for: \(text)")
    }
}

@Test func hypeAdjectiveAfterBeExclaims() {
    for text in ["that dunk was bonkers", "this ramen is elite"] {
        assertNovel(text)
        #expect(marks(text).first == "!", "expected ! for: \(text)")
    }
}

@Test func burstPrefixFamiliesExclaim() {
    for text in [
        "no shot they blew that lead",
        "cant believe this weather today",
        "i cant stop laughing rn",
        "so incredibly proud of this team",
    ] {
        assertNovel(text)
        #expect(marks(text).first == "!", "expected ! for: \(text)")
    }
}

@Test func occasionWishesExclaimBeyondFixedList() {
    for text in ["happy tuesday everyone", "merry everything friends", "welcome home stranger"] {
        assertNovel(text)
        #expect(marks(text).first == "!", "expected ! for: \(text)")
    }
}

@Test func firstPersonCompletionKeepsExclamationAheadOfQuestion() {
    // comma-lists AC 1 moved "," into second everywhere; the v4 excited-news
    // tweak survives as ! third, still ahead of ? (spec comma-lists).
    for text in ["i finally organized the garage", "we just adopted a kitten"] {
        assertNovel(text)
        let m = marks(text)
        #expect(m.first == ".", "completion statements stay period-first: \(text)")
        #expect(m.count > 2 && m[1] == "," && m[2] == "!",
                "expected , second and ! third for: \(text)")
    }
}

@Test func exclamationGuardsHold() {
    // Superlative without a scope window is not a burst ("worst part" -> ,)
    let noWindow = "smartest kid in his class maybe"
    assertNovel(noWindow)
    #expect(marks(noWindow).first != "!")
    // Plain wh-questions keep asking.
    let stillQuestion = "what are we bringing saturday"
    assertNovel(stillQuestion)
    #expect(marks(stillQuestion).first == "?")
}
