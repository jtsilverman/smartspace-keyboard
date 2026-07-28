import Testing
@testable import PunctuationEngine

/// In-memory stand-in for the extension's UserDefaults-backed store.
private final class MemoryOutcomeStore: OutcomeLogStore {
    var lines: [String] = []
    func load() -> [String] { lines }
    func save(_ lines: [String]) { self.lines = lines }
}

// Spec stats-wire AC 1: the double-space interaction lifecycle.
@Suite struct OutcomeTrackerTests {
    @Test func insertThenFinishKeepsTheGuess() {
        var t = OutcomeTracker()
        t.smartInsert(rule: .question, guess: "?", wordCount: 5)
        let record = t.finish()
        #expect(record == OutcomeRecord(rule: .question, guess: "?", kept: "?",
                                        cycleTaps: 0, lengthBucket: .medium))
    }

    @Test func cyclingBumpsTapsAndUpdatesKept() {
        var t = OutcomeTracker()
        t.smartInsert(rule: .question, guess: "?", wordCount: 2)
        t.cycled(to: ".")
        t.cycled(to: "!")
        let record = t.finish()
        #expect(record == OutcomeRecord(rule: .question, guess: "?", kept: "!",
                                        cycleTaps: 2, lengthBucket: .short))
    }

    @Test func finishClearsAndIdleFinishIsNil() {
        var t = OutcomeTracker()
        #expect(t.finish() == nil)
        t.smartInsert(rule: .fallback, guess: ".", wordCount: 10)
        #expect(t.finish() != nil)
        #expect(t.finish() == nil)
    }

    @Test func newInsertOverwritesUnfinishedInteraction() {
        var t = OutcomeTracker()
        t.smartInsert(rule: .question, guess: "?", wordCount: 3)
        t.smartInsert(rule: .exclamation, guess: "!", wordCount: 12)
        let record = t.finish()
        #expect(record == OutcomeRecord(rule: .exclamation, guess: "!", kept: "!",
                                        cycleTaps: 0, lengthBucket: .long))
    }

    @Test func abandonDropsTheActiveInteraction() {
        var t = OutcomeTracker()
        t.smartInsert(rule: .question, guess: "?", wordCount: 3)
        t.cycled(to: ".")
        t.abandon()
        #expect(t.finish() == nil)
    }
}

// Spec stats-wire AC 2: text-free line codec.
@Suite struct OutcomeRecordCodecTests {
    @Test func encodesToAReadableLine() {
        let record = OutcomeRecord(rule: .question, guess: "?", kept: ".",
                                   cycleTaps: 2, lengthBucket: .short)
        #expect(record.encodedLine == "question|?|.|2|short")
    }

    @Test func roundTripsForAllRulesAndMarks() {
        for rule in PredictionRule.allCases {
            for mark in ["?", ".", "!", ",", "\u{201C}"] {
                let record = OutcomeRecord(rule: rule, guess: mark, kept: mark,
                                           cycleTaps: 3, lengthBucket: .long)
                #expect(OutcomeRecord(line: record.encodedLine) == record)
            }
        }
    }

    @Test func malformedLinesDecodeNil() {
        #expect(OutcomeRecord(line: "") == nil)
        #expect(OutcomeRecord(line: "question|?|.") == nil)                 // too few
        #expect(OutcomeRecord(line: "nosuchrule|?|.|0|short") == nil)       // bad rule
        #expect(OutcomeRecord(line: "question|?|.|many|short") == nil)      // bad taps
        #expect(OutcomeRecord(line: "question|?|.|0|gigantic") == nil)      // bad bucket
    }
}

// Spec stats-wire AC 3: capped persistent log.
@Suite struct OutcomeLogTests {
    @Test func appendsPersistAndReload() {
        let store = MemoryOutcomeStore()
        var log = OutcomeLog(store: store)
        let record = OutcomeRecord(rule: .comma, guess: ",", kept: ",",
                                   cycleTaps: 0, lengthBucket: .medium)
        log.append(record)
        let reloaded = OutcomeLog(store: store)
        #expect(reloaded.records == [record])
    }

    @Test func capsAtTwoThousandDroppingOldest() {
        let store = MemoryOutcomeStore()
        var log = OutcomeLog(store: store)
        for i in 0..<(OutcomeLog.cap + 5) {
            log.append(OutcomeRecord(rule: .fallback, guess: ".",
                                     kept: i == OutcomeLog.cap + 4 ? "!" : ".",
                                     cycleTaps: 0, lengthBucket: .short))
        }
        #expect(log.records.count == OutcomeLog.cap)
        #expect(log.records.last?.kept == "!")
    }

    @Test func statsMatchOutcomeStatsOfRecords() {
        let store = MemoryOutcomeStore()
        var log = OutcomeLog(store: store)
        log.append(OutcomeRecord(rule: .question, guess: "?", kept: "?",
                                 cycleTaps: 0, lengthBucket: .short))
        log.append(OutcomeRecord(rule: .question, guess: "?", kept: ".",
                                 cycleTaps: 1, lengthBucket: .long))
        #expect(log.stats == OutcomeStats(log.records))
        #expect(log.stats.total == 2)
        #expect(log.stats.keptWithoutCycling == 1)
    }

    @Test func malformedPersistedLinesAreSkipped() {
        let store = MemoryOutcomeStore()
        store.lines = ["question|?|?|0|short", "garbage", "also|bad"]
        let log = OutcomeLog(store: store)
        #expect(log.records.count == 1)
        #expect(log.records.first?.rule == .question)
    }
}
