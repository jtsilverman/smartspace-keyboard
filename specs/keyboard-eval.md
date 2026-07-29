---
status: active
---

# Keyboard-wide blind eval + invariant iteration (eval v4)

## Intent

Extend the frozen eval suite from punctuation+typos to every behavior a real keyboard must get right, authored blind (no author sees engine source -- same charter rule as EVAL.md v3), then iterate the engine against it invariant-first until improvements are Pareto-blocked (any further gain costs another category). Goal per Jake: optimize capability against real-life keyboard use without overfitting code logic; one patch must fix a class of failures, never one row.

## New sets (each dev/test split, frozen after assembly)

1. **Capitalization** (~200 rows): sentence-start, after `.?!`, NOT after abbreviations, standalone `i` -> `I`, plus must-not-cap rows (mid-sentence, after comma, URLs).
2. **Contractions + smart symbols** (~250 rows): dont->don't class; ambiguous forms that must NOT auto-apostrophize (id, ill, well, hell, shell, cant-in-names); curly-quote direction (open/close/nested/decades '90s/5'10"); em-dash, ellipsis.
3. **Autocorrect protection + typo breadth** (~300 rows): words that must survive uncorrected -- slang (lol, tbh, finna), acronyms, names, brands, URLs, emails, hashtags, @handles, stylization (sooo, yesss) -- plus new casual-register typo pairs (existing typo-pairs.tsv stays frozen).
4. **Completions** (~100 rows): prefix + context -> acceptable completion set (top-3 credit).
5. **E2E scenarios** (~40): full realistic messages as keystroke scripts (incl. double-space smart punctuation, backspace-undo) -> expected final text.

## Acceptance criteria

1. All five sets authored by fresh-context agents with zero repo access, protocol + raw files under `eval/` (charter compliance documented in EVAL.md).
2. Harness: pure-logic sets (1,2, protection-logic subset) score via `swift test` targets; UITextChecker-dependent sets (3-typos, 4) score in the simulator test target like the typo benchmark; scenarios run in the XCUITest suite.
3. Baseline scored per set dev/test, recorded in EVAL.md before any engine change.
4. Iteration loop: cluster dev misses by invariant, patch the invariant (rule-level, named), re-run ALL suites (new + blind v3 + real-v3 + typo + regression); a change that lifts one set by tanking another is rejected. Stop when Pareto-blocked; record the frontier in EVAL.md.
5. Test halves report aggregate only, never inspected.

## Non-goals

- No regeneration of the frozen punctuation benchmark or typo-pairs.tsv.
- No ML classifier (documented rules-plateau successor, separate task).
- No device-only verification (simulator parity accepted, device owed at 5.1).

## Progress

- [x] Spec
- [ ] Blind authoring (5 agent sets)
- [ ] QC + assembly + dev/test split
- [ ] Harness
- [ ] Baseline scores -> EVAL.md v4 section
- [ ] Invariant iteration to Pareto frontier
- [ ] Final frontier recorded, PR
