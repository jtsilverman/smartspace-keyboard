import Testing
import PunctuationEngine

@Test func emptyContextFallsBackToPeriod() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "").first == Candidate(text: "."))
}
