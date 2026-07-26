import Testing
import PunctuationEngine

@Test func spaceTapsCycleThroughCandidatesAndWrap() {
    var cycle = CycleState(candidates: [
        Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!")
    ])
    #expect(cycle.current == Candidate(text: "?"))
    #expect(cycle.advance() == Candidate(text: "."))
    #expect(cycle.advance() == Candidate(text: "!"))
    #expect(cycle.advance() == Candidate(text: "?"))
}
