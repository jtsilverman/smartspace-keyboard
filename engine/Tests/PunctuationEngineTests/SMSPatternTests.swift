import Testing
import PunctuationEngine

@Test func txtSpeakQuestionWordsDetected() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "wat u doing there").first == Candidate(text: "?"))
    #expect(engine.candidates(before: "r u meeting them tonight").first == Candidate(text: "?"))
}

@Test func questionInLastCommaClauseDetected() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "i just got home babe, are you still awake").first == Candidate(text: "?"))
    #expect(engine.candidates(before: "sup, you in town").first == Candidate(text: "?"))
}

@Test func pronounProgressiveCheckInDetected() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "u still painting ur wall").first == Candidate(text: "?"))
    #expect(engine.candidates(before: "you leaving soon").first == Candidate(text: "?"))
}

@Test func trailingWhWordDetected() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "call me for wat").first == Candidate(text: "?"))
    #expect(engine.candidates(before: "you did what").first == Candidate(text: "?"))
}

@Test func warmOpenersRankExclamationFirst() {
    let engine = PunctuationEngine()
    #expect(engine.candidates(before: "thank you baby").first == Candidate(text: "!"))
    #expect(engine.candidates(before: "thanks so much").first == Candidate(text: "!"))
    #expect(engine.candidates(before: "hey there").first == Candidate(text: "!"))
    #expect(engine.candidates(before: "yes baby").first == Candidate(text: "!"))
    #expect(engine.candidates(before: "i cant wait to see you").first == Candidate(text: "!"))
}

@Test func warmOpenerGuardsStayCalm() {
    let engine = PunctuationEngine()
    // long hey-sentence is a statement, not a greeting burst
    #expect(engine.candidates(before: "hey i left my charger at your place").first == Candidate(text: "."))
    // yes + longer clause reads as a plain answer
    #expect(engine.candidates(before: "yes i can make it tomorrow").first == Candidate(text: "."))
}
