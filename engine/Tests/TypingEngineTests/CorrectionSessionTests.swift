import Testing
import TypingEngine

@Test func undoReturnsOriginalWordAndProtectsItFromRecorrection() {
    var session = CorrectionSession()
    session.recordCorrection(original: "teh", corrected: "the")
    #expect(session.undoLast() == "teh")

    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "hello teh", session: session) == .noChange)
}

@Test func undoProtectionIsCaseInsensitive() {
    var session = CorrectionSession()
    session.recordCorrection(original: "teh", corrected: "the")
    _ = session.undoLast()
    #expect(session.isProtected("Teh"))
    #expect(session.isProtected("TEH"))
}

@Test func undoWithNothingRecordedReturnsNil() {
    var session = CorrectionSession()
    #expect(session.undoLast() == nil)
    #expect(session.undoLast() == nil)
}

@Test func undoAppliesToTheMostRecentCorrectionOnly() {
    var session = CorrectionSession()
    session.recordCorrection(original: "teh", corrected: "the")
    session.recordCorrection(original: "realy", corrected: "really")
    #expect(session.undoLast() == "realy")
    #expect(session.undoLast() == nil)
    #expect(!session.isProtected("teh"))
}

@Test func unprotectedWordsStillGetCorrectedWithASessionPresent() {
    var session = CorrectionSession()
    session.recordCorrection(original: "teh", corrected: "the")
    _ = session.undoLast()

    let engine = CorrectionEngine(checker: checker)
    #expect(engine.decision(for: "that was realy", session: session) ==
        .correct(to: "really", alternatives: ["real"]))
}
