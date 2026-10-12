# SmartSpace

A custom iOS keyboard that chooses the punctuation a double-tap of the space bar inserts — period, question mark, exclamation point, comma, or opening quote — from the sentence just typed. The choice runs on the device.

The system keyboard turns that same gesture into a period every time. SmartSpace keeps the gesture and inserts the mark the sentence calls for.

## What it does

Type the way you already do. The first space inserts a space. A second space within 0.3 seconds replaces it with a punctuation mark and a trailing space. Further spaces swap that mark for the next candidate, in place, with no backspace and no picker. Any other key accepts the mark.

| You type | Double-space inserts |
|---|---|
| `how are you` | `how are you? ` |
| `congrats on the new job` | `congrats on the new job! ` |
| `i made it home` | `i made it home. ` |
| `hey mom` | `hey mom, ` |

A wrong first guess is one more space away. `how are you` ranks `?` first, then `.`, `!`, `,`, and `"`, and the cycle wraps. The host app can remove marks from that list. With smart double-space turned off, the gesture falls back to the system period.

The rest of the keyboard exists so it can be used all day: a layout and hit targets built to match the system keyboard, autocorrect and a three-slot suggestion bar, auto-capitalization and contractions, smart quotes and dashes, number and symbol planes, long-press alternates, space-bar cursor drag, a repeating backspace, key previews, light and dark appearance, a return key that follows the text field (Send, Go, Search), and an emoji panel with search and recents. Secure and password fields stay on the system keyboard. That is iOS, and the extension is absent there.

## How it works

SmartSpace is two layers. A pure Swift package holds every decision. A thin UIKit keyboard extension draws the keys and applies the edits.

### Keyboard extension

`KeyboardViewController` is a `UIInputViewController`, the principal class of an `com.apple.keyboard-service` extension (`en-US`, ASCII-capable). It renders the key planes, reads touches, and writes through `textDocumentProxy`. Ranking, cycling, and the other typing decisions live in the Swift package.

`SmartSpaceBar` is the gesture state machine. It takes a timestamp and a closure that returns ranked candidates. The first tap is a space. A second tap inside the 0.3 second window asks for candidates and inserts the top one. Later taps cycle. The controller deletes the previous space or mark only after checking that the document still ends with what it wrote, so a moved cursor cannot corrupt the text.

The host app is a small SwiftUI shell: a practice field, a setup guide, settings, and an on-device stats screen. Settings and stats cross the app/extension boundary through an app-group `UserDefaults` suite. The Xcode project is generated from `app/project.yml` (XcodeGen). The `.xcodeproj` is a build artifact and is gitignored.

### On-device punctuation

`PunctuationEngine.prediction(before:)` ranks candidates from the text before the cursor. The ranker is a deterministic rules engine in the keyboard process: question shape (wh-words, auxiliary inversion, verb-first requests, tag questions, short check-ins), exclamation cues and all-caps shouting, comma continuations (subordinate clauses, vocatives, discourse lead-ins), list commas, and opening quotes after speech introducers. Anything that matches none of those ranks a period first. An abbreviation such as `Mr` or `e.g.` still ranks a period first. After a sentence that already ends in `.` `?` or `!`, the engine returns no candidates, so a second double-space does not stack punctuation.

`PersonalRanking` can reorder a rule's candidates after five deliberate corrections of that rule. A keep counts only when the user cycled on purpose. The counters store the rule, the guess, the kept mark, and a coarse length bucket. The live ranker is this rules engine. `specs/punctuation-encoder.md` is a draft for a later on-device encoder; the repository contains no model file.

### How context is captured

On each double-space the extension reads `textDocumentProxy.documentContextBeforeInput`, the text the host app exposes before the cursor, and strips the space the first tap just inserted. The engine then takes the current sentence: the span after the last `.` `?` or `!`.

That string is whatever the host app provides, often about the last sentence or two, and it is not reliable in every app. An empty or unusable context degrades to a period. The engine has no conversation history beyond that string.

### Privacy

Inference and storage stay on the device.

- The extension requests no Full Access. Its entitlements are the app group only. There is no network client in the keyboard or the host app.
- The outcome log that feeds stats and personal ranking is text-free by construction: rule identity, guessed mark, kept mark, cycle taps, and a length bucket. The stats screen says so, and it computes its counts from that log.
- Raw-sentence capture exists as an engine type and a TSV export format for a future, user-initiated export. It is not wired into the keyboard.

Dictation is out of reach: a keyboard extension cannot use the microphone.

## Tech stack

- Swift 6. The engine package targets iOS 17 and macOS 13 and has no external dependencies.
- UIKit keyboard extension and a SwiftUI host app. Deployment target iOS 17. Bundle ids `com.jtsilverman.smartspace` and `com.jtsilverman.smartspace.keyboard`.
- `UITextChecker` and `UILexicon` for spelling, contacts, and text replacements, behind a seam the package tests stub.
- XcodeGen for the Xcode project. Python under `eval/` assembles the frozen corpora.

## Project structure

```
engine/                 Swift package
  Sources/PunctuationEngine/   double-space ranking, cycling, outcomes
  Sources/TypingEngine/        autocorrect, layout, gestures, suggestions, emoji
  Tests/                  package tests, including the punctuation corpora
app/
  project.yml             XcodeGen spec (source of truth)
  SmartSpace/             host app: practice, onboarding, settings, stats
  SmartSpaceKeyboard/     keyboard extension
  Shared/                 spell-checker binding, app-group stores
  SmartSpaceTests/        simulator unit tests (real UITextChecker)
  SmartSpaceUITests/      driven UI tests
eval/                     corpus assembly, blind annotations, parity tooling
docs/                     architecture, conventions, runbooks, decisions
specs/                    feature specs
PRODUCT.md  UX.md  WORKPLAN.md  EVAL.md
```

## Build and run

**Engine tests** run with the Swift 6 toolchain:

```bash
cd engine
swift test
```

Filter one suite with `swift test --filter PunctuationEngineTests` or `swift test --filter TypingEngineTests`.

**The app** needs Xcode with the iOS 17 SDK and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
cd app
xcodegen generate
open SmartSpace.xcodeproj
```

Select the `SmartSpace` scheme and a simulator or a device, then run. That installs the host app and the keyboard extension together. On the device: Settings → General → Keyboard → Keyboards → Add New Keyboard → SmartSpace. Leave Allow Full Access off.

Automatic signing is set in `app/project.yml`. Change `DEVELOPMENT_TEAM` if you are not building with the team checked in there. A free Personal Team provisioning profile expires after seven days.

Simulator tests that depend on `UITextChecker` have a reset step and must run alone. Corpus scoring commands live in `docs/runbooks/build-and-eval.md`.

## Status

In development. The marketing version in `app/project.yml` is 0.1.0.

`WORKPLAN.md` marks the punctuation engine, the typing logic, and the keyboard extension complete, with the extension exercised in the simulator. The host app's practice field, setup guide, settings, and stats screen are in the tree; enable-detection and visual polish are still open. A pass on a physical iPhone in Messages, Notes, and Safari is still owed. TestFlight and App Store submission are open items in that workplan.

Accuracy is measured on frozen corpora that were labeled without seeing the engine source: a blind set and a real-SMS set, scored as first-guess and one-extra-tap accuracy. Current figures and the ship bar live in `EVAL.md`.

The current build is an English (`en-US`) iPhone keyboard.

## Roadmap

Recorded in `WORKPLAN.md` and still open:

- Finish the host app: detect that the keyboard is enabled, and polish onboarding, settings, and stats.
- Install a TestFlight build and type with it daily, including the real-device pass still owed from the keyboard phase.
- Write the App Store metadata and privacy labels, then submit. The privacy label the project is written for is that nothing is collected.

`specs/punctuation-encoder.md` (draft) describes a follow-on experiment: a small on-device encoder, quantized for the keyboard extension, that would replace or augment the rules only if it improves first-guess accuracy without regressing one-tap accuracy, and only if it fits the extension's memory and latency limits. No candidate model has been trained in this repo.

## Further reading

- `PRODUCT.md` — feature tiers and constraints
- `UX.md` — behavior, in plain language
- `WORKPLAN.md` — phased build order and what is checked off
- `EVAL.md` — benchmark charter and recorded scores
- `docs/architecture/two-layers.md` — what the package owns and what the app owns
- `docs/decisions/nothing-leaves-the-device.md` — why there is no network and no Full Access
