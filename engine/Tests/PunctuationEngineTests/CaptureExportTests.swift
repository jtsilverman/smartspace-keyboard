import Testing
import PunctuationEngine

@Test func exportWritesOneMarkTabSentenceLinePerRecord() {
    let tsv = CaptureExport.tsv([
        CaptureRecord(sentence: "how are you", kept: "?"),
        CaptureRecord(sentence: "i went home", kept: "."),
    ])
    #expect(tsv == "?\thow are you\n.\ti went home\n")
}

@Test func sentenceTabsAndNewlinesAreNormalizedToSpaces() {
    let tsv = CaptureExport.tsv([
        CaptureRecord(sentence: "wait\tfor\nme", kept: "!"),
    ])
    #expect(tsv == "!\twait for me\n")
}

@Test func emptyCaptureExportsEmptyString() {
    #expect(CaptureExport.tsv([]) == "")
}

/// Property: line count always equals record count -- no sentence content
/// can split or merge lines.
@Test func lineCountMatchesRecordCountForGeneratedSentences() {
    let fragments = ["hi", "a\tb", "x\ny", "\n", "\t", "", "🎉", "end.", "\r\n"]
    var records: [CaptureRecord] = []
    for a in fragments {
        for b in fragments {
            records.append(CaptureRecord(sentence: a + " " + b, kept: "."))
        }
    }
    let lines = CaptureExport.tsv(records).split(separator: "\n", omittingEmptySubsequences: false)
    // trailing newline yields one final empty fragment
    #expect(lines.count == records.count + 1)
    #expect(lines.last == "")
}
