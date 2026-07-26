import Testing
import PunctuationEngine

/// Ship gate (spec AC7c): top candidate matches the label on >=90% of the
/// labeled corpus. Prints every miss so rule work has a target list.
@Test func corpusAccuracyMeetsShipGate() {
    #expect(corpus.count >= 100)

    let engine = PunctuationEngine()
    var top1Misses: [(text: String, expected: String, got: [String])] = []
    var top2Misses: [(text: String, expected: String, got: [String])] = []
    for item in corpus {
        let ranked = engine.candidates(before: item.text).map(\.text)
        if ranked.first != item.label {
            top1Misses.append((text: item.text, expected: item.label, got: ranked))
            if !ranked.prefix(2).contains(item.label) {
                top2Misses.append((text: item.text, expected: item.label, got: ranked))
            }
        }
    }

    let top1 = Double(corpus.count - top1Misses.count) / Double(corpus.count)
    let top2 = Double(corpus.count - top2Misses.count) / Double(corpus.count)
    print("CORPUS TOP-1: \(corpus.count - top1Misses.count)/\(corpus.count) = \(Int(top1 * 100))%  (right on the first guess)")
    print("CORPUS TOP-2: \(corpus.count - top2Misses.count)/\(corpus.count) = \(Int(top2 * 100))%  (right within one cycle tap)")
    for m in top1Misses {
        print("MISS top-1: \"\(m.text)\" expected \(m.expected) got \(m.got.joined(separator: " "))")
    }
    for m in top2Misses {
        print("MISS top-2: \"\(m.text)\" expected \(m.expected) got \(m.got.joined(separator: " "))")
    }
    #expect(top1 >= 0.9)
    #expect(top2 >= 0.97)
}
