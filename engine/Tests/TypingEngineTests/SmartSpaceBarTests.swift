import Testing
import TypingEngine
import PunctuationEngine

// The hero-feature state machine (spec AC 1-6): first space inserts a space,
// a second within the window swaps it for the top engine candidate, further
// space taps cycle candidates in place, any other key ends the cycle, and an
// empty candidate list (right after terminal punctuation) degrades to a
// plain space.

private let marks = [
    Candidate(text: "?"), Candidate(text: "."), Candidate(text: "!"),
    Candidate(text: ",", endsSentence: false), Candidate(text: "\"", endsSentence: false),
]

@Test func singleSpaceInsertsSpace() {
    var bar = SmartSpaceBar()
    #expect(bar.spaceTapped(at: 1.0, candidates: { marks }) == .insertSpace)
}

@Test func doubleSpaceWithinWindowInsertsTopCandidate() {
    var bar = SmartSpaceBar()
    _ = bar.spaceTapped(at: 1.0, candidates: { marks })
    let d = bar.spaceTapped(at: 1.2, candidates: { marks })
    #expect(d == .insertMark(Candidate(text: "?")))
}

@Test func slowSecondSpaceStaysPlain() {
    var bar = SmartSpaceBar()
    _ = bar.spaceTapped(at: 1.0, candidates: { marks })
    #expect(bar.spaceTapped(at: 2.0, candidates: { marks }) == .insertSpace)
}

@Test func spaceAfterInsertCyclesInPlaceAndWraps() {
    var bar = SmartSpaceBar()
    _ = bar.spaceTapped(at: 1.0, candidates: { marks })
    _ = bar.spaceTapped(at: 1.2, candidates: { marks })
    #expect(bar.spaceTapped(at: 5.0, candidates: { marks }) == .replaceMark(Candidate(text: ".")))
    #expect(bar.spaceTapped(at: 9.0, candidates: { marks }) == .replaceMark(Candidate(text: "!")))
    _ = bar.spaceTapped(at: 10.0, candidates: { marks })
    _ = bar.spaceTapped(at: 11.0, candidates: { marks })
    // fifth advance wraps back to the top candidate
    #expect(bar.spaceTapped(at: 12.0, candidates: { marks }) == .replaceMark(Candidate(text: "?")))
}

@Test func anyOtherKeyEndsTheCycle() {
    var bar = SmartSpaceBar()
    _ = bar.spaceTapped(at: 1.0, candidates: { marks })
    _ = bar.spaceTapped(at: 1.2, candidates: { marks })
    bar.nonSpaceKey()
    #expect(bar.spaceTapped(at: 1.4, candidates: { marks }) == .insertSpace)
}

@Test func emptyCandidatesDegradeToPlainSpace() {
    var bar = SmartSpaceBar()
    _ = bar.spaceTapped(at: 1.0, candidates: { [] })
    #expect(bar.spaceTapped(at: 1.2, candidates: { [] }) == .insertSpace)
}

@Test func plainDoubleSpaceDoesNotChainIntoATripleInsert() {
    var bar = SmartSpaceBar()
    _ = bar.spaceTapped(at: 1.0, candidates: { [] })
    _ = bar.spaceTapped(at: 1.2, candidates: { [] })
    // a third quick space after two plain ones is still just a space
    #expect(bar.spaceTapped(at: 1.4, candidates: { [] }) == .insertSpace)
}
