import Foundation

/// The student: a next-word model in the Gboard shape (embedding, one LSTM,
/// projection, tied softmax), trained by engine/tools/model/train.py and
/// mapped from Resources/contextmodel.bin. It reads the last 24 words before
/// a candidate, the window it was trained on, where the pair table reads one
/// (unit 4b of specs/autocorrect-parity.md, piloted by specs/autocorrect-loop.md
/// unit 5).
///
/// Ids are the word's record index in WordRank plus three specials (pad,
/// start, unknown), so the file carries no vocabulary. Weights stay float16
/// in the mapped file and convert as they are read, so the model costs the
/// extension no heap beyond one hidden state. The engine scores every
/// candidate of one commit against the same words, so the sentence is run
/// once and its softmax kept for the next candidate: a cold call is the LSTM
/// and the vocabulary pass, a warm one is one dot product.
public struct ContextModel: ContextScoring {
    private static let file = MappedFile.resource("contextmodel", magic: "SSCM", version: 1)
    private static let vocab = file.u32(at: 8)
    private static let embed = file.u32(at: 12)
    private static let hidden = file.u32(at: 16)
    private static let arrays: [String: Int] = {
        var out: [String: Int] = [:]
        var offset = 24
        for _ in 0..<file.u32(at: 20) {
            let n = file.u8(at: offset); offset += 1
            let name = String(decoding: file.bytes(at: offset, count: n), as: UTF8.self); offset += n
            let ndim = file.u32(at: offset); offset += 4
            var count = 1
            for _ in 0..<ndim { count *= file.u32(at: offset); offset += 4 }
            out[name] = offset
            offset += 2 * count
        }
        return out
    }()
    private static let words = 10_000
    private static let pad = 0, start = 1, unknown = 2, specials = 3
    private static let window = 24
    private static let embedBase = base("embed"), WxBase = base("lstm.Wx"), WhBase = base("lstm.Wh")
    private static let biasBase = base("lstm.bias"), projBase = base("proj.weight"), projBiasBase = base("proj.bias")

    private static func base(_ name: String) -> Int { arrays[name]! }

    /// The last sentence scored: its projected state and the softmax
    /// denominator, so the candidates of one commit share one forward pass.
    private final class Memo: @unchecked Sendable {
        private let lock = NSLock()
        private var previous: [Int] = [-1]
        private var state: [Float] = []
        private var top: Float = 0
        private var sum: Float = 0

        func scores(for ids: [Int], compute: ([Int]) -> ([Float], Float, Float)) -> ([Float], Float, Float) {
            lock.lock(); defer { lock.unlock() }
            if ids != previous {
                (state, top, sum) = compute(ids)
                previous = ids
            }
            return (state, top, sum)
        }
    }
    private static let memo = Memo()

    /// Below this probability the model has no evidence for the sequence:
    /// the caller falls through to its next tiebreak and a split is not a
    /// pair. 3e-4 is where the pair table's 300,000-count floor sits for a
    /// word seen a billion times in the web corpus it came from.
    static let evidenceFloor = 3e-4

    public init() {}

    @inline(__always)
    private static func weight(_ base: Int, _ i: Int) -> Float {
        Float(file.base.loadUnaligned(fromByteOffset: base + 2 * i, as: Float16.self))
    }

    private static func id(of word: String) -> Int {
        guard let i = WordRank.index(ofLower: word.lowercased()), i < words else { return unknown }
        return i + specials
    }

    /// The projected hidden state after reading `start` then `ids`.
    private static func state(after ids: [Int]) -> [Float] {
        let E = embed, H = hidden
        var h = [Float](repeating: 0, count: H)
        var c = [Float](repeating: 0, count: H)
        var gates = [Float](repeating: 0, count: 4 * H)
        for id in [start] + ids {
            for g in 0..<(4 * H) {
                var acc = weight(biasBase, g)
                for e in 0..<E { acc += weight(WxBase, g * E + e) * weight(embedBase, id * E + e) }
                for k in 0..<H { acc += weight(WhBase, g * H + k) * h[k] }
                gates[g] = acc
            }
            for k in 0..<H {
                let i = sigmoid(gates[k]), f = sigmoid(gates[H + k])
                let g = tanh(gates[2 * H + k]), o = sigmoid(gates[3 * H + k])
                c[k] = f * c[k] + i * g
                h[k] = o * tanh(c[k])
            }
        }
        var out = [Float](repeating: 0, count: E)
        for e in 0..<E {
            var acc = weight(projBiasBase, e)
            for k in 0..<H { acc += weight(projBase, e * H + k) * h[k] }
            out[e] = acc
        }
        return out
    }

    /// One forward pass: the projected state, the largest logit, and the
    /// softmax denominator over the vocabulary.
    private static func forward(_ ids: [Int]) -> ([Float], Float, Float) {
        let e = state(after: ids)
        let E = embed
        var logits = [Float](repeating: 0, count: vocab)
        var top: Float = -.infinity
        for v in 0..<vocab {
            var acc: Float = 0
            for k in 0..<E { acc += weight(embedBase, v * E + k) * e[k] }
            logits[v] = acc
            top = max(top, acc)
        }
        var sum: Float = 0
        for v in 0..<vocab { sum += exp(logits[v] - top) }
        return (e, top, sum)
    }

    private static func sigmoid(_ x: Float) -> Float { 1 / (1 + exp(-x)) }

    /// P(word | previous), or nil when the word is off the list or the
    /// probability sits under the evidence floor.
    public func likelihood(of word: String, after previous: [String]) -> Double? {
        let target = Self.id(of: word)
        guard target != Self.unknown else { return nil }
        let ids = previous.suffix(Self.window).map(Self.id)
        let (e, top, sum) = Self.memo.scores(for: ids, compute: Self.forward)
        var logit: Float = 0
        for k in 0..<Self.embed { logit += Self.weight(Self.embedBase, target * Self.embed + k) * e[k] }
        let p = Double(exp(logit - top) / sum)
        return p >= Self.evidenceFloor ? p : nil
    }
}
