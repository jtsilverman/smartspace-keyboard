/// One opt-in captured example: the raw sentence and the mark the user
/// kept. Only ever stored locally, only when capture is toggled on; the
/// export file grows the frozen eval sets and later trains the model.
public struct CaptureRecord: Equatable, Sendable {
    public let sentence: String
    public let kept: String

    public init(sentence: String, kept: String) {
        self.sentence = sentence
        self.kept = kept
    }
}

/// Serializes captured examples for export. Hand-rolled TSV because the
/// engine targets carry no Foundation and the eval-set workflow ingests
/// line-per-example text.
public enum CaptureExport {
    /// One line per record: kept mark, tab, sentence. Tabs and newlines
    /// inside a sentence are normalized to spaces so a line is always
    /// exactly one record.
    public static func tsv(_ records: [CaptureRecord]) -> String {
        records.map { record in
            let flat = String(record.sentence.map { $0.isWhitespace ? " " : $0 })
            return record.kept + "\t" + flat + "\n"
        }.joined()
    }
}
