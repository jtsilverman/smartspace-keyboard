import Testing
import TypingEngine

// Stock commits an autocorrect when a word-ending key lands: space,
// return, and sentence punctuation all commit (research wf_1ac9e72d-a76,
// axis 2: "space, punctuation and Return all commit"). Apostrophe and
// hyphen stay word characters ("don't", "well-known") and never commit.
// The delimiter set is the pinned fact; space and return commit through
// their own key paths.

@Test func sentencePunctuationCommitsACorrection() {
    for c in [".", ",", "!", "?", ":", ";"] {
        #expect(AutocorrectController.isCommitDelimiter(Character(c)))
    }
}

@Test func wordInternalMarksNeverCommit() {
    for c in ["'", "\u{2019}", "-"] {
        #expect(!AutocorrectController.isCommitDelimiter(Character(c)))
    }
}

@Test func lettersDigitsAndSpaceAreNotDelimiters() {
    for c in ["a", "Z", "5", " "] {
        #expect(!AutocorrectController.isCommitDelimiter(Character(c)))
    }
}
