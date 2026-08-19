import Testing
import TypingEngine

// Stock held-delete semantics (spec stock-parity, matrix row "backspace
// hold"): the repeat starts as single characters, then a sustained hold
// switches to whole whitespace-delimited chunks. A trailing whitespace
// run with a newline deletes alone, so the hold stops at each line it
// unmakes. Tick counts are the pinned structure; wall-clock cadence
// lives in the controller.

@Test func firstTwentyTicksDeleteSingleCharacters() {
    var r = BackspaceRepeater()
    for _ in 1...BackspaceRepeater.characterTicks {
        #expect(r.tick(before: "hello world") == .characters(1))
    }
}

@Test func sustainedHoldSwitchesToWholeWordChunks() {
    var r = BackspaceRepeater()
    for _ in 1...BackspaceRepeater.characterTicks { _ = r.tick(before: "abc def") }
    #expect(r.tick(before: "abc def") == .word(3))
    #expect(r.tick(before: "abc ") == .word(4))
}

@Test func wordChunkEatsTrailingSpacesWithTheWord() {
    var r = BackspaceRepeater()
    for _ in 1...BackspaceRepeater.characterTicks { _ = r.tick(before: "x") }
    #expect(r.tick(before: "hello  world ") == .word(6))
}

@Test func punctuationRunsAreChunksLikeWords() {
    var r = BackspaceRepeater()
    for _ in 1...BackspaceRepeater.characterTicks { _ = r.tick(before: "x") }
    #expect(r.tick(before: "wait...") == .word(7))
}

@Test func newlineRunDeletesAloneBeforeTheWordBehindIt() {
    var r = BackspaceRepeater()
    for _ in 1...BackspaceRepeater.characterTicks { _ = r.tick(before: "x") }
    #expect(r.tick(before: "hello\n") == .word(1))
    #expect(r.tick(before: "hello\n\n") == .word(2))
    #expect(r.tick(before: "hi \n") == .word(2))
}

@Test func whitespaceOnlyContextDeletesTheRun() {
    var r = BackspaceRepeater()
    for _ in 1...BackspaceRepeater.characterTicks { _ = r.tick(before: "x") }
    #expect(r.tick(before: "   ") == .word(3))
}

@Test func emptyContextInWordPhaseDeletesNothing() {
    var r = BackspaceRepeater()
    for _ in 1...BackspaceRepeater.characterTicks { _ = r.tick(before: "x") }
    #expect(r.tick(before: "") == .word(0))
}

@Test func releaseResetsToCharacterPhase() {
    var r = BackspaceRepeater()
    for _ in 1...(BackspaceRepeater.characterTicks + 3) { _ = r.tick(before: "abc def") }
    r.reset()
    #expect(r.tick(before: "abc def") == .characters(1))
}
