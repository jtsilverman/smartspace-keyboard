# Build and eval

## Run the engine tests

No Xcode needed. From the repo root:

```
cd engine && swift test
```

One target:
```
cd engine && swift test --filter PunctuationEngineTests
cd engine && swift test --filter TypingEngineTests
```

One suite:
```
cd engine && swift test --filter BlindCorpusAccuracyTests
```

Build without running:
```
cd engine && swift build
```

This is the loop for every rule change. `WORKPLAN.md` Phases 1 and 2 finished entirely here.

## Regenerate the Xcode project

`app/project.yml` is the source of truth; `app/SmartSpace.xcodeproj` is a build artifact and is
gitignored. After any change to `project.yml`:

```
cd app && xcodegen generate
```

Never edit the project inside Xcode. The next generation overwrites it.

## Build and run on a device

Prerequisites: Xcode, and Jake's iPhone. The signing team in `project.yml` is `865ZN46D5H`, a free
Personal Team, so a device install lasts 7 days before it needs reinstalling.

1. `cd app && xcodegen generate`
2. Open `app/SmartSpace.xcodeproj`.
3. Select the `SmartSpace` scheme and the device.
4. Run. That installs the host app and the `SmartSpaceKeyboard` extension together.
5. On the device: Settings, General, Keyboard, Keyboards, Add New Keyboard, SmartSpace.
6. Leave Full Access off. It is never requested; see
   `docs/decisions/nothing-leaves-the-device.md`.

The `SmartSpace` scheme's test action runs `SmartSpaceTests` and `SmartSpaceUITests`.

A secure or password field swaps back to the stock keyboard. That is iOS behavior, not a bug.

## Run the simulator tests

`app/SmartSpaceTests` needs a real `UITextChecker`, so it runs in the simulator through
`xcodebuild`, not `swift test`.

**Before any checker-dependent run**, reset the learned state:

```
eval/v4/reset-keyboard-state.sh <udid>
```

That clears the system dynamic lexicon and the extension's `UserDefaults`. Both drift. `UITextChecker`
rankings adapt to typed text, and the outcome log trains `PersonalRanking`.

Then run the benchmark **solo**. Never alongside another `xcodebuild` session on the same simulator.
An XCUITest session running in parallel shifted typo miscorrections from 4 to 18.

The checker-dependent sets are protect, typos, completions, and scenarios.

## Score a corpus

The accuracy suites are ordinary tests; `swift test --filter` runs them and prints the score.

| Set | Suite | Reports |
|---|---|---|
| Blind benchmark, 1,196 rows | `BlindCorpusAccuracyTests` | The headline number. Dev and test halves, 598 each |
| Real-SMS v3, 638 rows | `RealCorpusV3AccuracyTests` | The reality check |
| Real-SMS v2.1 | `RealCorpusAccuracyTests` | Retired from reporting, kept as provenance |
| Rule regression | `CorpusAccuracyTests` | A tripwire, not a benchmark. Gates at top-1 90%, top-2 97% |

Top-1 is right on the first guess. Top-2 is right within one cycle tap, which is the product-truth
metric.

The ship gate is top-2 at or above 80% on blind test and at or above 85% on real-v3 test. As of the
2026-07-27 pass it is not met: 76 and 84.

## Record the stock oracle

The oracle is Apple's own answers to a frozen corpus of keystrokes
(`specs/autocorrect-parity.md` unit 0). Every autocorrect check scores agreement
with it, so it is recorded once and never re-labelled by hand.

The corpus regenerates deterministically; regeneration is what freezes it.

```
python3 eval/oracle/gen-corpus.py
```

That writes `eval/oracle/corpus/*.tsv` (400 rows in four slices, plus the
30-row drift subset) and `app/SmartSpaceUITests/OracleCorpus.swift`.

Record one slice at a time. Each run resets the learned keyboard state first,
and each slice stays under the 40-minute UI-suite cap.

```
xcodebuild build-for-testing -scheme SmartSpace -project app/SmartSpace.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ~/.smartspace-oracle/DD
python3 eval/oracle/record.py <udid> names
python3 eval/oracle/record.py <udid> nospace
python3 eval/oracle/record.py <udid> context
python3 eval/oracle/record.py <udid> sloppy
```

Rows land in `eval/oracle/stock-<date>.tsv`. Rerunning a slice resumes: ids
already in the file are skipped, so a run killed at row 90 costs 90 rows, not
the slice. Run solo, like every other checker-dependent suite.

## Prove the oracle is still ground truth

Stock's engine adapts to what it has typed. The drift slice re-types 30 held-back
rows and diffs them against the frozen recording:

```
python3 eval/oracle/record.py <udid> drift              # from a cleared lexicon
python3 eval/oracle/record.py <udid> drift --no-reset   # with the learned state
```

Run it after a full day of unrelated simulator sessions, never in the same
session as the recording. Each run writes `drift-<date>-reset.tsv` or
`drift-<date>-warm.tsv`, prints `DRIFT-RESULT <same>/<total>`, and exits
non-zero on any row that moved.

**As of 2026-08-20 this gate fails.** Both runs reproduced 28 of 30 rows and
both moved the same two, and clearing the lexicon did not restore the recorded
answers (`EVAL.md`). Treat `eval/oracle/stock-2026-08-19.tsv` as a recording
with a 6.7% instability, never as ground truth, until vision milestone 5 says
how autocorrect is judged instead.

## Regenerate a corpus

Corpus regeneration is its own commit and never rides along with an engine change.

```
eval/assemble.py eval/raw/pool.tsv eval/raw/ann1.tsv eval/raw/ann2.tsv eval/raw/ann3.tsv <out_dir>
```

That writes `BlindCorpus.swift`, `blind-labeled.tsv`, and `assembly-report.txt`. Gold is the majority
of the three blind annotators; generator intent is metadata, not a vote. A three-way disagreement
goes to the ambiguity slice, scored top-2 only. Exact-duplicate texts drop entirely when their
generator intents conflict and are kept once otherwise. The split is stratified by form and gold with
a fixed seed.

The v4 keyboard-wide corpora regenerate through `eval/v4/gen-corpus.py`, with the split from
`eval/v4/make-split.py`.

## Where status lives

`WORKPLAN.md` carries the phase checklist and ticks in the same branch as the work.
`specs/vision.md` carries the handoff paragraph and the decision log. `EVAL.md` carries the scores.
