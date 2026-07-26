import Testing
import PunctuationEngine

@Test func noCandidatesRightAfterTerminalPunctuation() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "how are you?").isEmpty)
    #expect(engine.candidates(before: "made it home. ").isEmpty)
}
