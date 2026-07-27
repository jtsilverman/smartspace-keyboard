---
status: active
---

# Autocorrect wiring (WORKPLAN 3.4)

## Intent

Wire the tested Phase 2 correction seam into the live keyboard: on word commit (space or return), the real `UITextChecker` decides via `CorrectionEngine` whether to auto-replace the word with Apple's top spelling suggestion; a 3-slot suggestion bar appears above the keys showing the original word (tap to undo, word becomes protected for the session) plus alternatives (tap to swap); `UILexicon` (contacts, text replacements) feeds the engine's lexicon so personal words are never corrected. This is the last big piece of "essentially the stock Apple keyboard" behavior the extension is missing.

## Acceptance criteria

1. In the simulator practice field, typing `teh` then space produces `the ` (top suggestion auto-applied) and the suggestion bar shows the original `teh` in slot 1 plus at most 2 alternatives (`AutocorrectController` truncates; bar never exceeds 3 slots). Grounding: the frozen typo benchmark already proves `teh -> the` is the top suggestion on this simulator (transposition category 60/60 corrected, EVAL.md baseline). XCUITest-verified via bar slot accessibility identifiers `suggestion-0/1/2`.
2. Tapping `teh` in the bar reverts the text to `teh ` and typing `teh` + space again later in the session does NOT re-correct it (undo-tap protection, no correction loops). XCUITest-verified.
3. Correctly spelled words, lexicon words, all-caps acronyms, and words already protected pass through unchanged: space inserts a plain space, no text rewrite.
4. Return commits the pending word the same way space does (correction fires before the newline).
5. `UILexicon` is requested once at keyboard load and its entries reach `CorrectionEngine`'s lexicon (engine-level test proves a lexicon word is never corrected; live wiring verified by code path, since simulator lexicon content is not controllable).
6. Tapping an alternative in the bar replaces the corrected word with that alternative.
7. The correction/bar orchestration is a pure state machine in `TypingEngine` (no UIKit), fully covered by `swift test`; the extension only translates its outputs into `textDocumentProxy` edits.
8. `SystemSpellChecker` exists in exactly one place (`app/Shared`), used by both the extension and the typo benchmark; benchmark report still runs (~90% corrected baseline).
9. Existing smoke tests updated where autocorrect changes typed text (`HiJ`, `u`); full simulator suite green.
10. Bar lifecycle at the seams (engine-level tests): backspace after a correction clears the bar (undo window closed, protection state unchanged); a second space inside the double-tap window after a correction runs the SmartSpaceBar punctuation path against the corrected text without interleaving edits; a bar undo-tap clears the SmartSpaceBar cycle window (`nonSpaceKey()`); the bar clears on the next word commit.

## Non-goals

- ContractionRule / SmartSymbols wiring (same commit boundary, separate follow-up unit; surfaced to Jake).
- Next-word prediction / QuickType-style suggestions while typing (bar only shows correction results).
- Settings toggle for autocorrect (4.2), but the code path branches at one point so the toggle drops in cleanly.
- Underline-and-offer UX; correction is auto-applied per UX.md.
- Any Full Access capability, network, or pasteboard use.

## Orientation findings (compact)

- Seam ready: `SpellChecking` protocol (`suggestions(for:) -> [String]`), `CorrectionEngine.decision(for:session:)` -> `.noChange | .correct(to:alternatives:)`, `CorrectionSession` (one undoable correction, `undoLast()` protects the word), `WordBoundary.lastWord(in:)`. `CorrectionEngine.init` takes `lexicon: Set<String>` built for UILexicon.
- Extension: programmatic UIKit, `rowsStack` with `heightAnchor == 216`; the input view's height is derived by autolayout from the pinned content (216 + 8 + 8 today), so inserting a fixed-40pt bar between `view.topAnchor` and `rows` grows the allocated keyboard height through the same constraint chain — no `preferredContentSize` needed; verify visually in the smoke run. Hook point: top of `.insertSpace` branch in `spaceTapped()` (KeyboardViewController.swift:314) + `returnTapped()`. House pattern for document edits: verify `documentContextBeforeInput` suffix before delete/insert (`.replaceMark` branch).
- `SystemSpellChecker: SpellChecking` already written but lives in the test target (TypoBenchmarkTests.swift:7-17); move to `app/Shared`, add `Shared` to `SmartSpaceTests.sources` in project.yml, delete test-local copy.
- Landmines: smoke test asserts exact text `"HiJ OK! How are u? "` which autocorrect will rewrite; suggestion-bar taps must call `spaceBar.nonSpaceKey()` to clear the double-tap cycle window; correction edits and SmartSpaceBar `.replaceMark` share the document tail (suffix-verify before every edit); memory ceiling -> one `UITextChecker` per checker call is fine (stateless), no caching layers.
- Tests: engine uses swift-testing (`import Testing`); app tests via `xcodegen generate` + `xcodebuild test -scheme SmartSpace -destination 'platform=iOS Simulator,id=DA42AC36-4E51-4733-B26B-4AE59DB29D2D'`.

## Design (creativity beat)

Alternatives considered: (a) wire UIKit-side directly in the view controller with ad-hoc ifs (fastest, but untestable and braids UI with decisions); (b) pure `AutocorrectController` state machine in TypingEngine that consumes commit events and emits document edits + bar content (chosen: testable off-device, extension stays a thin shell, matches SmartSpaceBar precedent); (c) 10x version: full QuickType prediction bar with frequency model (out of scope, ML phase). Simplest viable form: one type, `AutocorrectController`, holding `CorrectionEngine` + `CorrectionSession` + last-correction state; methods `wordCommitted(context:) -> Commit` (`.keep | .replace(original:corrected:alternatives:)`, alternatives capped at 2), `barTapped(slot:) -> BarAction` (`.undo(original:corrected:) | .swap(from:to:)`), `barContent`, `backspace()` (clears bar, keeps protection), next `wordCommitted` clears/refills the bar.

## Decomposition

1. RED: `AutocorrectControllerTests` in `engine/Tests/TypingEngineTests` (commit decisions, bar content, undo protection, swap, bar lifecycle) — committed failing.
2. GREEN: `AutocorrectController` in `engine/Sources/TypingEngine`.
3. Wire: move `SystemSpellChecker` to `app/Shared` (+ project.yml `SmartSpaceTests.sources`), UILexicon fetch, bar UI (slots get `accessibilityIdentifier` `suggestion-0/1/2`), hooks in `spaceTapped`/`returnTapped`/bar taps, smoke-test updates PLUS new XCUITest cases for AC1 (auto-correct + bar), AC2 (tap-to-undo + protection), AC6 (tap-to-swap). Simulator suite green.
4. Review, fix, PR.
