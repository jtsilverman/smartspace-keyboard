# Two layers

Say it in one sentence: a pure Swift package holds every decision the keyboard makes, and a thin
Xcode app wraps it in a UIKit keyboard extension.

SmartSpace is a full replacement iOS keyboard whose one difference from stock is that
double-tapping the space bar inserts the punctuation the sentence actually calls for.

## Why the split

The engine is a Swift package that builds and tests with the `swift` CLI alone. No Xcode, no
simulator, no device. That is what let Phases 1 and 2 of `WORKPLAN.md` finish before Xcode was ever
installed, and it is why the corpus benchmarks run in seconds.

Anything that needs UIKit, a real `UITextChecker`, or a touch surface lives in the Xcode side.

## Layer one: `engine/`

A Swift 6 package, `swift-tools-version: 6.0`, platforms iOS 17 and macOS 13. Two library products,
no external dependencies.

**`PunctuationEngine`** decides what a double-space inserts.

| File | Owns |
|---|---|
| `PunctuationEngine.swift` | The rules. Wh-words, auxiliary inversion, imperative disambiguation, tags, exclamation cues, abbreviations |
| `Prediction.swift` | The rule identity carried on each outcome |
| `CycleState.swift` | Insert-then-cycle as pure state: candidate order, the cycling window, wrap |
| `Outcome.swift`, `OutcomeWiring.swift` | The text-free outcome record: rule fired, guess, kept mark, cycle taps, length bucket |
| `PersonalRanking.swift` | Per-rule win and loss counters that nudge candidate order after a 5-outcome threshold |
| `Capture.swift` | The opt-in raw-sentence capture and its export format |

`Candidate` is text-shaped rather than an enum of sentence enders, so a continuation mark like an
opening quote joins without changing the interface. Its `endsSentence` flag separates the two kinds:
`ranked()` sets it false for the comma and the opening quote, true for everything else. That is what
tells the keyboard whether to auto-capitalize next.

An abbreviation period is terminal. The `Candidate` doc comment says the flag is false for a period
after "Mr", and it is not: the abbreviation branch calls the same `ranked()` and gets
`endsSentence: true`. `AbbreviationTests.swift` pins that with a comment naming it a v4 criterion
change, and `EVAL.md` lists "smart period always terminal (1.4 criterion updated)". The abbreviation
rule is now only about ranking the period first. The doc comment in `PunctuationEngine.swift` is
stale.

**`TypingEngine`** depends on `PunctuationEngine` and owns everything else a keyboard decides:
autocorrect (`AutocorrectController`, `CorrectionEngine`, `CorrectionSession`), capitalization and
contractions, the layout and key geometry (`KeyboardLayout`, `KeyZoneMap`, `BiasedKeyResolver`,
`CalloutGeometry`, `KeyTheme`), the suggestion bar (`SmartSpaceBar`, `NextWordPredictor`), gestures
(`SpacebarCursorDrag`, `BackspaceRepeater`, `FunctionKeySlide`), and the emoji catalog.

Every `UITextChecker` call sits behind a seam, stubbed in the package tests and bound to the real
checker in `app/Shared/SystemSpellChecker.swift`.

## Layer two: `app/`

Three source groups plus two test targets.

| Group | Is |
|---|---|
| `app/SmartSpace/` | The host app: onboarding, settings, stats |
| `app/SmartSpaceKeyboard/` | The extension: `KeyboardViewController`, `KeyTouchSurface`, `KeyPopView`, `AlternatesCalloutView`, `DefaultsRecentsStore` |
| `app/Shared/` | Compiled into both: `SystemSpellChecker`, `SharedStores`, `AppGroupProbe` |
| `app/SmartSpaceTests/` | Simulator unit tests, including the typo benchmark against the real `UITextChecker` |
| `app/SmartSpaceUITests/` | Driven UI tests: cursor drag, emoji panel, fast typing, hold behavior |

The extension declares `NSExtensionPointIdentifier: com.apple.keyboard-service` with
`KeyboardViewController` as its principal class, `IsASCIICapable: true`, primary language `en-US`.
Bundle ids are `com.jtsilverman.smartspace` and `com.jtsilverman.smartspace.keyboard`, deployment
target iOS 17.

## The Xcode project is generated

`app/project.yml` is the XcodeGen spec and the source of truth. `.gitignore` ignores `*.xcodeproj`,
and `git ls-files app/SmartSpace.xcodeproj` returns nothing: the project on disk is a build artifact.
Edit `project.yml`, then regenerate.

Both app targets take the engine as a local Swift package at `../engine`, pulling `TypingEngine` and
`PunctuationEngine` as products. The signing base sets `DEVELOPMENT_TEAM: 865ZN46D5H`, Jake's free
Personal Team, which gives 7-day device provisioning.

## The eval corpora

`eval/` holds the corpus pipeline: the raw annotator pool, the assembly script, the contamination
report, and a `v4/` generation set. `assemble.py` turns the raw pool plus three blind annotations
into `BlindCorpus.swift`, taking the majority vote as gold, dropping conflicting duplicates, and
stratifying the split by form and gold with a fixed seed.

The generated Swift corpora live beside the tests in `engine/Tests/PunctuationEngineTests/`:
`BlindCorpus.swift`, `RealCorpusV3.swift`, `RealCorpus.swift`, `Corpus.swift`, `ListCorpus.swift`.

## What is not here

No CI workflow. No `.github` directory. `.claude/` holds only a scheduler lock; there are no
project skills, agents, or rules.
