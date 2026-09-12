import Foundation

/// The student: a next-word model in the Gboard shape (embedding, one LSTM,
/// projection, tied softmax), trained by engine/tools/model/train.py and
/// mapped from Resources/contextmodel.bin. It reads the whole sentence
/// before a candidate, which is the limit the pair table has (unit 4b of
/// specs/autocorrect-parity.md, piloted by specs/autocorrect-loop.md unit 5).
///
/// Ids are the word's record index in WordRank plus three specials (pad,
/// start, unknown), so the file carries no vocabulary. Weights stay float16
/// in the mapped file and convert as they are read, so the model costs the
/// extension no heap beyond one hidden state.
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

    /// Below this probability the model has no evidence for the sequence:
    /// the caller falls through to its next tiebreak and a split is not a
    /// pair. 3e-4 is where the pair table's 300,000-count floor sits for a
    /// word seen a billion times in the web corpus it came from.
    static let evidenceFloor = 3e-4

    public init() {}

    private static func weight(_ name: String, _ i: Int) -> Float {
        Float(file.base.loadUnaligned(fromByteOffset: arrays[name]! + 2 * i, as: Float16.self))
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
                var acc = weight("lstm.bias", g)
                for e in 0..<E { acc += weight("lstm.Wx", g * E + e) * weight("embed", id * E + e) }
                for k in 0..<H { acc += weight("lstm.Wh", g * H + k) * h[k] }
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
            var acc = weight("proj.bias", e)
            for k in 0..<H { acc += weight("proj.weight", e * H + k) * h[k] }
            out[e] = acc
        }
        return out
    }

    private static func sigmoid(_ x: Float) -> Float { 1 / (1 + exp(-x)) }

    /// P(word | previous), or nil when the word is off the list or the
    /// probability sits under the evidence floor.
    public func likelihood(of word: String, after previous: [String]) -> Double? {
        let target = Self.id(of: word)
        guard target != Self.unknown else { return nil }
        let e = Self.state(after: previous.suffix(8).map(Self.id))
        let E = Self.embed
        var logits = [Float](repeating: 0, count: Self.vocab)
        var top: Float = -.infinity
        for v in 0..<Self.vocab {
            var acc: Float = 0
            for k in 0..<E { acc += Self.weight("embed", v * E + k) * e[k] }
            logits[v] = acc
            top = max(top, acc)
        }
        var sum: Float = 0
        for v in 0..<Self.vocab { sum += exp(logits[v] - top) }
        let p = Double(exp(logits[target] - top) / sum)
        return p >= Self.evidenceFloor ? p : nil
    }
}
