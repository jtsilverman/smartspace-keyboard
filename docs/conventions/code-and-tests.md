# Code and test conventions

One answer per question. A reviewer can reject a change from this file alone.

## Where the logic goes

Every decision the keyboard makes belongs in `engine/`, as pure Swift with no UIKit import. That is
what keeps it testable with `swift test` and no simulator.

`app/` holds only what needs a device: view controllers, touch surfaces, the real `UITextChecker`,
storage. A rule written inside `KeyboardViewController` is in the wrong place.

An external API sits behind a seam. `SpellChecking` is the pattern: stubbed in the package tests,
bound to `app/Shared/SystemSpellChecker.swift` in the app.

## Where a test goes

| Kind | Directory |
|---|---|
| Punctuation rules and cycling | `engine/Tests/PunctuationEngineTests/` |
| Typing, layout, autocorrect, gestures | `engine/Tests/TypingEngineTests/` |
| Anything needing a real `UITextChecker` or the touch surface | `app/SmartSpaceTests/` |
| Driven UI behavior | `app/SmartSpaceUITests/` |

A corpus file lives beside the tests that read it: `BlindCorpus.swift`, `RealCorpusV3.swift`,
`Corpus.swift`, `ListCorpus.swift` in `PunctuationEngineTests/`, and the v4 corpora in
`TypingEngineTests/` and `app/SmartSpaceTests/`.

## Corpus rules

`EVAL.md` is the charter. Read it before touching any corpus. Two principles bind everything:
**wide, not deep**, and **independent of the code**. No corpus row may be authored, labeled, or
edited by anything that has seen the engine source.

- **Frozen.** A benchmark row never changes in a commit that also touches engine source.
  Regeneration or expansion is its own commit.
- **Dev is studied, test is not.** Dev misses may be inspected. The test half reports aggregate
  numbers only; its sentences are never read.
- **Annotation inputs are shuffled.** Ordered input produced block-stamping annotators, archived in
  `eval/raw/`. Randomized order is what made the votes independent.
- **Report per label and per scenario form.** Misses cluster by invariant, and a change that lifts
  one mark by tanking another must stay visible.

`Corpus.swift` is a rule-regression suite, not a benchmark. It was written with knowledge of the
rules, roughly one row per branch. It catches a broken rule and never a missing one, and it keeps
hard gates as tripwires: top-1 at or above 90%, top-2 at or above 97%.

## Fix the invariant, not the sentence

Rule improvement is invariant-first. Cluster the dev misses by scenario type, name the invariant,
write the general rule. Never one patch per sentence.

## The checker-state protocol

`UITextChecker` rankings adapt to text already typed. An XCUITest session shifted typo
miscorrections from 4 to 18 on a rerun. Checker-dependent benchmarks (protect, typos, completions,
scenarios) run **solo**, after `eval/v4/reset-keyboard-state.sh <udid>`, never alongside another
`xcodebuild` session on the same simulator.

That script resets two kinds of learned state, not one. The system's dynamic lexicon, and the
extension's own `UserDefaults`, because the outcome log trains `PersonalRanking`: five smoke-test
question-to-period cycles permanently flipped question predictions to a period, observed 2026-07-29.

`EVAL.md` calls the script `reset-lexicon.sh`. No such file exists; the script is
`eval/v4/reset-keyboard-state.sh`, and its name reflects the wider reset. The `EVAL.md` line is
stale.

## The Xcode project is generated, never edited

`app/project.yml` is the source of truth. `.gitignore` ignores `*.xcodeproj` and the project is not
tracked. A target, a build setting, or a dependency changes in `project.yml`, then the project gets
regenerated. Editing the project in Xcode loses the change on the next generation.

## The parity invariant

Key positions, hit areas, previews, drag-to-type, sounds, and the emoji pane must be
indistinguishable from stock. A change that improves the punctuation engine while moving a key has
failed, whatever its tests say. See
`docs/decisions/muscle-memory-outranks-everything.md`.

The reverse-engineered visual constants live in the engine as tested data. `specs/stock-design-parity.md`
and `specs/stock-parity-test-matrix.md` carry them.

## Git

The build is TDD in visible pairs. A `RED:` commit adds the failing test, the matching `GREEN:`
commit makes it pass. Other subjects lead with the area and a colon: `Bar:`, `Callout:`, `Chrome:`,
`Render:`, `Theme:`, `Sound:`, `Matrix:`, `Specs:`, `Vision:`. The subject names the behavior, not
the file.

Branch per task, Jake merges the PR. Never commit to main. Stage with `git add <file>`.

Unit status lives in `WORKPLAN.md` and is ticked in the same branch as the work.

## What never lands in the repo

`.gitignore` covers `.build/`, `.DS_Store`, `*.xcodeproj`, `xcuserdata/`, and `DerivedData/`.
