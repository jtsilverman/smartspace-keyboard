import XCTest

/// Records what the real stock keyboard produces for the frozen oracle
/// corpus (`specs/autocorrect-parity.md` unit 0). Apple's own answers are the
/// gold labels every later unit is scored against, so this suite asserts
/// nothing about correctness: it types and it prints. `eval/oracle/record.sh`
/// parses the printed lines into `eval/oracle/stock-<date>.tsv`.
///
/// One test per slice, because a single 400-row test runs past the 40-minute
/// UI-suite cap (`wiki/patterns/ios-xcode-swift.md`). A run that dies mid-slice
/// resumes: `record.sh` passes the ids it already holds in `ORACLE_SKIP` and
/// the suite steps over them.
final class StockOracleTests: XCTestCase {

    func testRecordSloppy() throws { try record(slice: "sloppy") }
    func testRecordNospace() throws { try record(slice: "nospace") }
    func testRecordContext() throws { try record(slice: "context") }
    func testRecordNames() throws { try record(slice: "names") }

    /// Controlled probes (`eval/oracle/gen-probes.py`): one variable changes
    /// per row, so stock's answers model the rule rather than sampling it.
    func testRecordProbes() throws { try type(rows: oracleProbes, tag: "ORACLE") }

    /// The same probes inside a lowercase carrier. Alone, a probe sits at the
    /// start of the field where autocap capitalizes it and stock protects it
    /// as a name, so the carrier is what isolates the slip shape.
    func testRecordCarrierProbesFirstHalf() throws {
        try type(rows: Array(oracleCarrierProbes.prefix(91)), tag: "ORACLE")
    }

    func testRecordCarrierProbesSecondHalf() throws {
        try type(rows: Array(oracleCarrierProbes.dropFirst(91)), tag: "ORACLE")
    }

    /// The 30 held-back rows, re-typed. `record.sh --drift` runs this a day
    /// later and diffs the output against the frozen recording. Stock's engine
    /// adapts to what it has seen, so a drift slice that does not reproduce
    /// means the oracle is not ground truth and check 1 fails.
    func testRecordDrift() throws {
        let rows = oracleSlices.values.flatMap { $0 }
            .filter { oracleDriftIDs.contains($0.id) }
            .sorted { $0.id < $1.id }
        XCTAssertEqual(rows.count, 30, "drift slice lost rows")
        try type(rows: rows, tag: "ORACLE-DRIFT")
    }

    private func record(slice: String) throws {
        guard let rows = oracleSlices[slice] else {
            XCTFail("unknown slice \(slice)")
            return
        }
        try type(rows: rows, tag: "ORACLE")
    }

    // MARK: - Typing

    private func type(rows: [OracleRow], tag: String) throws {
        let skip = Set((ProcessInfo.processInfo.environment["ORACLE_SKIP"] ?? "")
            .split(separator: ",").map(String.init))
        let app = XCUIApplication()
        app.launch()
        let field = focusStock(app)
        let keys = try letterFrames(app)

        // The first row after bringup came back with its auto-shift missed
        // ("tell Jake" where every later row gives "Tell Jake"), so one
        // throwaway row absorbs the warm-up and no corpus row pays for it.
        clear(app, field)
        for character in "hello " {
            tap(app, character: character, offset: CGVector(dx: 0, dy: 0), keys: keys)
        }
        _ = settled(field)

        var done = 0
        for row in rows where !skip.contains(row.id) {
            clear(app, field)
            for (index, character) in row.typed.enumerated() {
                let offset = index < row.offsets.count ? row.offsets[index] : CGVector(dx: 0, dy: 0)
                tap(app, character: character, offset: offset, keys: keys)
            }
            // The final word commits on a space; without it stock's correction
            // for the last word never lands and every row would end untouched.
            tap(app, character: " ", offset: CGVector(dx: 0, dy: 0), keys: keys)
            let produced = settled(field)
            XCTAssertFalse(produced.contains("\t"), "row \(row.id) produced a tab")
            print("\(tag)\t\(row.slice)\t\(row.id)\t\(produced)")
            done += 1
        }
        print("\(tag)-DONE rows=\(done) skipped=\(rows.count - done)")
    }

    /// Cell centres for the 26 letters and the space bar, read once. Frames do
    /// not move when the shift state flips the cap titles, so one read serves
    /// the whole slice and the suite never re-queries mid-row.
    private func letterFrames(_ app: XCUIApplication) throws -> [Character: CGRect] {
        var frames: [Character: CGRect] = [:]
        for character in "abcdefghijklmnopqrstuvwxyz" {
            let lower = app.keys[String(character)]
            let upper = app.keys[String(character).uppercased()]
            if lower.exists { frames[character] = lower.frame }
            else if upper.exists { frames[character] = upper.frame }
        }
        frames[" "] = app.keys["space"].frame
        XCTAssertEqual(frames.count, 27, "stock keyboard did not expose every letter")
        return frames
    }

    /// Taps one character at its cell centre plus the row's authored offset.
    /// The point is clamped into the letter row's own bounds: an unclamped
    /// sloppy offset on an edge key reaches shift or delete, and a row that
    /// deletes its own text records nothing about autocorrect. The clamp is
    /// pure geometry, so the same points reach our engine later.
    private func tap(_ app: XCUIApplication, character: Character,
                     offset: CGVector, keys: [Character: CGRect]) {
        guard let cell = keys[character] else {
            XCTFail("no key for \(character)")
            return
        }
        let bounds = character == " " ? cell : rowBounds(for: character, keys: keys)
        let x = min(max(cell.midX + offset.dx, bounds.minX + 1), bounds.maxX - 1)
        let y = min(max(cell.midY + offset.dy, bounds.minY + 1), bounds.maxY - 1)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: x, dy: y)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))
    }

    private static let rows: [String] = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]

    private func rowBounds(for character: Character, keys: [Character: CGRect]) -> CGRect {
        let row = Self.rows.first { $0.contains(character) } ?? Self.rows[0]
        let frames = row.compactMap { keys[$0] }
        let minX = frames.map(\.minX).min() ?? 0
        let maxX = frames.map(\.maxX).max() ?? 0
        let minY = frames.map(\.minY).min() ?? 0
        let maxY = frames.map(\.maxY).max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - Field

    /// Corrections land asynchronously, so a single read catches the
    /// pre-correction text. Read until two reads agree.
    private func settled(_ field: XCUIElement) -> String {
        var last = fieldText(field)
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            let now = fieldText(field)
            if now == last { return now }
            last = now
        }
        return last
    }

    private func clear(_ app: XCUIApplication, _ field: XCUIElement) {
        let deadline = Date().addingTimeInterval(30)
        while fieldText(field) != "", Date() < deadline {
            app.keys["delete"].press(forDuration: 2.0)
        }
        XCTAssertEqual(fieldText(field), "", "field never cleared")
    }
}
