import Testing
import TypingEngine

// Stock trailing-space absorption (research wf_1ac9e72d-a76, axes 2+3):
// after the keyboard itself inserts a space (completion accept, or the
// space that auto-committed a correction), sentence punctuation typed
// next eats that space so the mark attaches to the word: "hello " + ","
// becomes "hello,". Only an armed auto-space absorbs; a user-typed space
// never does. The arm is one-shot.

@Test func armedAutoSpaceAbsorbsSentencePunctuation() {
    for c in [".", ",", "!", "?", ":", ";"] {
        var s = TrailingAutoSpace()
        s.arm()
        #expect(s.deletions(forTyping: Character(c), context: "hello ") == 1)
    }
}

@Test func lettersDigitsAndQuotesNeverAbsorb() {
    for c in ["a", "5", "\"", "'"] {
        var s = TrailingAutoSpace()
        s.arm()
        #expect(s.deletions(forTyping: Character(c), context: "hello ") == 0)
    }
}

@Test func unarmedSpaceNeverAbsorbs() {
    var s = TrailingAutoSpace()
    #expect(s.deletions(forTyping: ".", context: "hello ") == 0)
}

@Test func armIsOneShot() {
    var s = TrailingAutoSpace()
    s.arm()
    #expect(s.deletions(forTyping: ".", context: "hello ") == 1)
    #expect(s.deletions(forTyping: ".", context: "hello") == 0)
}

@Test func aMissedChanceAlsoConsumesTheArm() {
    var s = TrailingAutoSpace()
    s.arm()
    #expect(s.deletions(forTyping: "a", context: "hello ") == 0)
    #expect(s.deletions(forTyping: ".", context: "hello a ") == 0)
}

@Test func contextWithoutTheTrailingSpaceCannotAbsorb() {
    var s = TrailingAutoSpace()
    s.arm()
    #expect(s.deletions(forTyping: ".", context: "hello") == 0)
}

@Test func disarmClearsTheArm() {
    var s = TrailingAutoSpace()
    s.arm()
    s.disarm()
    #expect(s.deletions(forTyping: ".", context: "hello ") == 0)
}
