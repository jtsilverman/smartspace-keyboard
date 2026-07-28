---
status: active
---

# Wire smart quotes, dashes, and contractions (Phase 2.2 rules go live)

## Intent

The last built-but-unwired typing niceties reach the keys, matching stock Apple behavior: typing `"` or `'` inserts the correct curly quote for its position, `--` collapses to an em dash, and apostrophe-less contractions fix themselves at word commit (`dont` -> `don't`, `i` -> `I`, `DONT` -> `DON'T`) with the same undo-and-protect suggestion-bar treatment autocorrect already has — tap the original in the bar and it reverts, never to be auto-fixed again this session.

## Acceptance criteria

1. Engine (`CorrectionEngine.decision`, swift-test): a committed contraction word returns `.correct(to: fixed, alternatives: [])` — `dont` -> `don’t`, `i` -> `I`, `Dont` -> `Don’t`, `DONT` -> `DON’T` (contraction outranks the all-caps acronym guard), `i'm` -> `I’m` (typed-apostrophe path); non-contraction words fall through to the spell checker unchanged.
2. Engine: lexicon and session-protection guards outrank the contraction fix — a protected `dont` (post-undo) and a lexicon `dont` both return `.noChange`.
2b. Engine: an already-correct form is left alone — `I` and `don’t` return `.noChange` (the contraction step only fires when the fix differs from the typed word; otherwise a phantom `I -> I` bar entry could be undo-tapped, permanently protecting `i` and killing the fix for the session).
3. Live (XCUITest): typing `dont` + space in the practice field yields `don’t ` with the bar showing `dont` in slot 0; tapping it reverts to `dont ` and a later `dont` + space stays unfixed (protection).
4. Live (XCUITest): on the 123 plane, typing `"`, letters, `"` produces `“…”` (opening then closing curly); typing `--` produces `—` (second hyphen collapses the first).
5. Typo benchmark still runs; report observed (contraction path may shift a few common-misspelling rows — report, not gate).
6. Full simulator suite green.

## Non-goals

- Settings toggle (4.2) — the branch point is `CorrectionEngine.decision`, already single.
- Growing the curated contraction table.
- Word completions in the bar (next unit).

## Orientation findings (compact)

- `ContractionRule.transform(_:) -> String?` (curated table + `i'`/`i’` prefix path + recase incl. all-caps); `SmartSymbols.decision(forTyping:before:) -> .insert(String) | .replacePrevious(with: String)` (curly quotes by opener context, `--` -> em dash, everything else passthrough). Both tested (TypingRuleInvariantTests).
- Contraction integration point: `CorrectionEngine.decision` (TypingEngine/CorrectionEngine.swift:36-45), AFTER the lexicon and `session.isProtected` guards, BEFORE the all-caps acronym guard (DONT must fix; the guard would eat it). Returning `.correct` reuses the whole existing bar/undo/protection pipeline for free — `AutocorrectController`, the VC, and the smoke landmines stay untouched.
- SmartSymbols integration: `characterTapped` and `alternateTapped` currently `insertText(title)` raw. Route single-character titles through `SmartSymbols.decision` with `documentContextBeforeInput`; `.replacePrevious` = `deleteBackward()` + insert. Search-mode early return stays above it (query gets raw characters).
- `"` and `-` live on the 123 plane only (`KeyboardLayout.numberRows`); `'` is on both planes' shared bottom row. XCUITest reaches them via the existing `123` tap pattern (smoke test precedent).
- Benchmark: TypoBenchmark drives `CorrectionEngine` with bare typo words; contraction-table hits ("dont" class) now resolve deterministically before UITextChecker.

## Design (creativity beat)

Alternatives: (a) VC-side pre-pass calling ContractionRule before `applyAutocorrectOnCommit` (skips the undo/protection pipeline — a contraction misfire could not be reverted-and-protected, violating the no-correction-loops contract); (b) chosen — contraction step inside `CorrectionEngine.decision` (single ordering authority, bar/undo/protection free, engine-testable); (c) 10x: full text-replacement expansion via UILexicon phrases — out of scope. Simplest viable: ~4 lines in CorrectionEngine, ~10 in the VC key path.

## Decomposition

1. RED: `CorrectionDecisionTests` additions (AC1-2) — committed failing.
2. GREEN: contraction step in `CorrectionEngine.decision`.
3. Wire: SmartSymbols routing in `characterTapped`/`alternateTapped`; `SmartTypingTests` XCUITest (AC3-4); benchmark observed; suite green.
4. Review, fix, PR (base main).
