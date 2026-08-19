/// Our own candidate source, replacing `UITextChecker` (unit 1 of
/// specs/autocorrect-parity.md, vision milestone 5). `UITextChecker` sees one
/// word at a time, returns guesses alphabetically, and cannot propose two
/// words for one token, so missed spaces are impossible however good the
/// re-ranking above it.
public struct DictionarySpellChecker: SpellChecking {
    public init() {}

    public func suggestions(for word: String) -> [String] {
        []
    }
}
