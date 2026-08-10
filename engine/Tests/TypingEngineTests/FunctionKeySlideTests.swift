import Testing
import TypingEngine

// Stock one-gesture modifiers (research wf_1ac9e72d-a76, axis 1, and
// consumer-documented since iOS 8): touch shift (or 123), slide to a
// character, release -- the character commits with the modifier applied
// and the modifier restores. Release back on the function key is the
// plain tap. Release on nothing cancels. The machine is modifier-
// agnostic: the caller maps commitSlide to "capital letter" or "symbol
// then back to letters", and passes nil for zones that are neither the
// origin nor a character key.

@Test func tapOnTheFunctionKeyCommitsTheTap() {
    var s = FunctionKeySlide()
    #expect(s.began(1, function: "__shift") == .activate("__shift"))
    #expect(s.ended(1, key: "__shift") == .commitTap("__shift"))
}

@Test func slideToALetterCommitsThatLetter() {
    var s = FunctionKeySlide()
    _ = s.began(1, function: "__shift")
    #expect(s.moved(1, key: "a") == .highlight("a"))
    #expect(s.ended(1, key: "e") == .commitSlide(from: "__shift", to: "e"))
}

@Test func highlightTracksTheFingerAcrossKeysAndGaps() {
    var s = FunctionKeySlide()
    _ = s.began(1, function: "__more")
    #expect(s.moved(1, key: "1") == .highlight("1"))
    #expect(s.moved(1, key: nil) == .highlight(nil))
    #expect(s.moved(1, key: "2") == .highlight("2"))
}

@Test func returningToTheFunctionKeyReadsAsAPlainTap() {
    var s = FunctionKeySlide()
    _ = s.began(1, function: "__shift")
    _ = s.moved(1, key: "a")
    #expect(s.ended(1, key: "__shift") == .commitTap("__shift"))
}

@Test func releaseOnNothingCancels() {
    var s = FunctionKeySlide()
    _ = s.began(1, function: "__shift")
    _ = s.moved(1, key: "a")
    #expect(s.ended(1, key: nil) == .cancel("__shift"))
}

@Test func twoFingersSlideIndependently() {
    var s = FunctionKeySlide()
    _ = s.began(1, function: "__shift")
    _ = s.began(2, function: "__more")
    #expect(s.ended(2, key: "5") == .commitSlide(from: "__more", to: "5"))
    #expect(s.ended(1, key: "q") == .commitSlide(from: "__shift", to: "q"))
}

@Test func cancelledDropsTheTouch() {
    var s = FunctionKeySlide()
    _ = s.began(1, function: "__shift")
    #expect(s.cancelled(1) == .cancel("__shift"))
    #expect(s.ended(1, key: "a") == FunctionKeySlide.Event.none)
}

@Test func unknownTokensAreIgnored() {
    var s = FunctionKeySlide()
    #expect(s.moved(9, key: "a") == FunctionKeySlide.Event.none)
    #expect(s.ended(9, key: "a") == FunctionKeySlide.Event.none)
    #expect(s.cancelled(9) == FunctionKeySlide.Event.none)
}
