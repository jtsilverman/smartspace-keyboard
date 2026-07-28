/// Live plumbing for outcome records: the per-interaction lifecycle the
/// keyboard drives, the text-free line codec, and the capped persistent
/// log. The keyboard supplies a store (UserDefaults); tests use memory.

/// Tracks one double-space interaction from smart insert to the moment the
/// cycle ends. Pure state -- the keyboard calls the verbs.
public struct OutcomeTracker: Sendable {
    private var active: (rule: PredictionRule, guess: String, kept: String,
                         taps: Int, bucket: LengthBucket)?

    public init() {}

    /// A smart mark was inserted; a fresh interaction begins (an unfinished
    /// one is overwritten -- the keyboard finalizes before this in practice).
    public mutating func smartInsert(rule: PredictionRule, guess: String, wordCount: Int) {
        active = (rule, guess, guess, 0, LengthBucket(wordCount: wordCount))
    }

    /// A cycle tap swapped the mark in place.
    public mutating func cycled(to mark: String) {
        guard var current = active else { return }
        current.taps += 1
        current.kept = mark
        active = current
    }

    /// The document and the cycle state diverged (cursor moved mid-cycle):
    /// the ground truth is corrupted, drop the interaction without a record.
    public mutating func abandon() {
        active = nil
    }

    /// The cycle ended; returns the finished record and clears.
    public mutating func finish() -> OutcomeRecord? {
        defer { active = nil }
        guard let active else { return nil }
        return OutcomeRecord(rule: active.rule, guess: active.guess,
                             kept: active.kept, cycleTaps: active.taps,
                             lengthBucket: active.bucket)
    }
}

/// Text-free persistence line: rule|guess|kept|taps|bucket. Marks never
/// contain "|", so the separator is safe.
extension OutcomeRecord {
    public var encodedLine: String {
        "\(rule.rawValue)|\(guess)|\(kept)|\(cycleTaps)|\(lengthBucket.rawValue)"
    }

    public init?(line: String) {
        let parts = line.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 5,
              let rule = PredictionRule(rawValue: String(parts[0])),
              let taps = Int(parts[3]), taps >= 0,
              let bucket = LengthBucket(rawValue: String(parts[4])),
              !parts[1].isEmpty, !parts[2].isEmpty else { return nil }
        self.init(rule: rule, guess: String(parts[1]), kept: String(parts[2]),
                  cycleTaps: taps, lengthBucket: bucket)
    }
}

public protocol OutcomeLogStore {
    func load() -> [String]
    func save(_ lines: [String])
}

/// Capped record log, persisted on every append; malformed stored lines
/// (older versions, corruption) are skipped on load, never fatal.
public struct OutcomeLog {
    public static let cap = 2000

    private let store: OutcomeLogStore
    public private(set) var records: [OutcomeRecord]

    public init(store: OutcomeLogStore) {
        self.store = store
        records = store.load().compactMap(OutcomeRecord.init(line:)).suffix(Self.cap)
    }

    public mutating func append(_ record: OutcomeRecord) {
        records.append(record)
        if records.count > Self.cap { records.removeFirst(records.count - Self.cap) }
        store.save(records.map(\.encodedLine))
    }

    public var stats: OutcomeStats { OutcomeStats(records) }
}
