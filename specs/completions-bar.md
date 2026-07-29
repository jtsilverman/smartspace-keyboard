---
status: active
---

# Word completions in the suggestion bar (stock QuickType feel)

## Intent

While a word is being typed, the suggestion bar fills the way Apple's does: the word-as-typed in quotes on the left, then up to two dictionary completions ("keyb" -> keyboard). Tapping a completion finishes the word and adds a space; tapping the quoted verbatim word commits it as typed with a space AND protects it from autocorrect for the session (the stock verbatim slot's real job — dodging an unwanted correction before it happens). A just-applied correction still owns the bar until the next word starts; the first letter of the next word hands the bar to completions.

## Acceptance criteria

1. Engine (`AutocorrectController`, swift-test): a new `typingUpdate(context:)` drives bar state — non-empty partial last word yields `.completions(typed:completions:)` with at most 2 completions from the checker seam; empty partial (just committed, mid-space) leaves existing content untouched; a partial word replaces a lingering correction bar (undo window closes, protection intact).
2. Engine: `barContent` is a single authority enum (`.empty | .correction(slots) | .completions(typed:completions:)`); all existing correction-bar tests still pass re-expressed against it.
3. Engine: tapping the verbatim slot returns `.acceptTyped(word)` and protects the word (a later `wordCommitted` on it is `.keep`); tapping a completion returns `.complete(from:typed, to:completion)`; taps on an empty/typed-mismatched state are `.none`.
4. Engine: `SpellChecking` gains `completions(for prefix:) -> [String]` with a default `[]` implementation (existing fakes compile unchanged).
5. Device seam (SmartSpaceTests, simulator): `SystemSpellChecker.completions(for: "keyb")` contains "keyboard" (real `UITextChecker.completions`).
6. Live (XCUITest): typing `keyb` shows `completion-typed` ("keyb", quoted) plus at least one completion slot (`completion-1`); tapping it replaces the partial with that word + space (self-consistent against the slot's label, like the alternative-swap test).
7. Live (XCUITest): typing `teh` then tapping the verbatim slot yields `teh ` uncorrected; typing `teh` + space again later stays `teh` (verbatim tap protected it).
8. Correction-priority handoff: right after an autocorrect fires, the bar shows the correction (undo available); typing the first letter of the next word switches the bar to completions (engine test for the transition; live behavior implied by AC6 flow).
8b. Backspace repopulation (engine test): after `backspace()` clears a correction, a `typingUpdate` with the shrunken partial serves completions for it — backspacing into a word gives its completions, matching stock.
8c. Tap-time tail guard (VC): before executing `.acceptTyped`/`.complete`, the VC verifies `documentContextBeforeInput` still ends with the typed partial (same class of guard as the correction path's separator check); on mismatch the bar drops with no edit. No live test can race this deterministically — code-path check, mirroring the shipped correction guard.
9. Full simulator suite green; existing correction-bar UI tests (AutocorrectBarTests, SmartTypingTests) unchanged and passing.

## Non-goals

- Next-word prediction (no model; ML phase).
- Frequency/recency ranking of completions (checker order, capped 2).
- Settings toggle (4.2).
- Verbatim slot for the correction state (that state's slot 0 is the undo, unchanged).

## Orientation findings (compact)

- `AutocorrectController` owns bar state today via `active` + `barSlots`/`currentCorrected`/`barTapped(slot:)`; refactor to `barContent` enum + tap actions extended with `.acceptTyped`/`.complete`. Call sites: `refreshSuggestionBar()` renders, `suggestionTapped(_:)` dispatches, both in KeyboardViewController.
- Completion trigger points in the VC: after `insertSmart` in `characterTapped`/`alternateTapped` (document mode only, not emoji search), and after `backspaceTapped` (partial shrinks). All already funnel through handlers that end with predictable state; add one `refreshTypingCompletions()` call there reading `documentContextBeforeInput`.
- `WordBoundary.lastWord(in:)` gives the partial word (nil on trailing space — exactly the "empty partial" state).
- `CorrectionSession` protection is currently only reachable via `undoLast()`; verbatim-accept needs a public `protect(_:)` (one line + test).
- `SystemSpellChecker` (app/Shared) wraps UITextChecker; add `completions(for:)` using `completions(forPartialWordRange:in:language:)` on the full prefix range, `en_US`, same stateless pattern.
- Identifiers: `completion-typed`, `completion-1`, `completion-2` (correction state keeps `suggestion-N`).
- Bar priority rule lives in the controller, not the VC, and `refreshSuggestionBar()` NEVER calls `typingUpdate` — it only renders `barContent`. Exactly three functions trigger `typingUpdate` (characterTapped, alternateTapped, backspaceTapped, all past their emoji-search early returns); the commit-space path (`applyAutocorrectOnCommit`'s deferred render) therefore cannot stomp a fresh correction. The empty-partial no-op is defense in depth, not the primary mechanism.

## Design (creativity beat)

Alternatives: (a) separate `CompletionBar` type beside `AutocorrectController` (two writers to one surface — the VC must referee priority, braiding display policy into UIKit); (b) chosen — one controller, one `barContent` authority, priority encoded in state transitions; (c) 10x: learned ranking from outcome records — ML phase. Simplest viable: enum + two verbs + one seam method with a default.

## Decomposition

1. RED: controller `barContent`/`typingUpdate`/tap-action tests + `CorrectionSession.protect` test + seam default test — committed failing.
2. GREEN: controller refactor + session protect + protocol extension.
3. Wire: `SystemSpellChecker.completions`, VC render/dispatch/trigger points, `SystemSpellCheckerTests` completion test, `CompletionBarTests` XCUITest (AC6-7). Suite green.
4. Review, fix, PR (base `feat/smart-symbols-wire`).
