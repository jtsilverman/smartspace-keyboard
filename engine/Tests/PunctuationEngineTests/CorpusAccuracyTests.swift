import Testing
import PunctuationEngine

/// Ship gate (spec AC7c): top candidate matches the label on >=90% of the
/// labeled corpus. Prints every miss so rule work has a target list.
@Test func corpusAccuracyMeetsShipGate() {
    #expect(corpus.count >= 100)

    let engine = PunctuationEngine()
    var misses: [(text: String, expected: String, got: String)] = []
    for item in corpus {
        let got = engine.candidates(before: item.text).first?.text ?? ""
        if got != item.label {
            misses.append((text: item.text, expected: item.label, got: got))
        }
    }

    let accuracy = Double(corpus.count - misses.count) / Double(corpus.count)
    print("CORPUS ACCURACY: \(corpus.count - misses.count)/\(corpus.count) = \(Int(accuracy * 100))%")
    for m in misses {
        print("MISS: \"\(m.text)\" expected \(m.expected) got \(m.got)")
    }
    #expect(accuracy >= 0.9)
}
