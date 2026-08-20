# SmartSpace

A full replacement iOS keyboard whose one difference from stock is that double-tapping the space bar
inserts the punctuation the sentence actually calls for.

**Status: in development.** The engine and its evaluation suite are complete and run today. The
keyboard extension builds and runs on device. Not on the App Store.

## The idea

The stock iPhone keyboard turns a double space into a period, always. Type "how are you" and double
space, and you get "how are you. " when the sentence obviously wanted a question mark. Apple offers
one on/off toggle and locks the system keyboard against third-party modification.

SmartSpace reads the sentence you just typed and picks the ending mark from context. If the guess is
wrong, tapping space again cycles to the next candidate in place, with no backspacing and no picker.
Default candidates are `.` `?` `!`; `,` `:` `;` `-` are available in settings. Triple-space gives an
ellipsis.

## How it is built

Two layers, split so the interesting half needs no Xcode.

**`engine/`** is a Swift 6 package with no external dependencies, built and tested with the `swift`
CLI alone.

| Component | Owns |
|---|---|
| `PunctuationEngine` | The rules: wh-words, auxiliary inversion, imperative disambiguation, tag questions, exclamation cues, abbreviations |
| `CycleState` | Insert-then-cycle as pure state: candidate order, the cycling window, wrap |
| `PersonalRanking` | Per-rule win and loss counters that nudge candidate order after a five-outcome threshold |
| `Outcome` | A text-free outcome record: rule fired, guess, kept mark, cycle taps, length bucket |

**`app/`** is a thin Xcode wrapper: a UIKit keyboard extension plus a host app. Everything needing
UIKit, a real `UITextChecker`, or a touch surface lives here.

`Candidate` is text-shaped rather than an enum of sentence enders, so a continuation mark like an
opening quote joins the candidate list without changing the interface. Its `endsSentence` flag is
what tells the keyboard whether to auto-capitalize the next word.

## Evaluation

Two principles govern the benchmark: wide rather than deep, and independent of the code. No corpus
row is authored, labeled, or edited by anything that has seen the engine source.

- **Blind benchmark**, 1,196 rows. Sentences authored by fresh-context generators with no repo
  access, across 18 scenario forms and 3 registers. Gold labels are the majority of 3 independent
  annotators working in shuffled order, blind to generator intent. Label-stratified dev/test split.
- **Real-SMS v3**, 638 rows from the UCI SMS corpus, relabeled by 3 blind annotators. 270 of 638
  original sender labels were overturned, because one keystroke is not gold.
- **Keyboard-wide v4**: capitalization, contractions and smart symbols, autocorrect protection,
  casual typos, completions, and end-to-end keystroke scenarios.
- **Rule-regression suite**: not a benchmark. Roughly one row per rule branch. It catches a broken
  rule, never a missing one.

Current held-out test results:

| Set | Result |
|---|---|
| Blind benchmark, top-2 | 61/76 (80%) |
| Real-SMS v3, top-2 | 67/85 (79%) |
| Autocorrect protection | 97 |
| Completions | 95 |
| Capitalization | 92 |
| End-to-end scenarios | 92 (36/39) |

Top-2 means the right mark appeared within one cycle tap, which is the product-truth metric. The
ship gate is top-2 at or above 80% blind and 85% real-v3, and it is not yet met. The remaining gap
is open-vocabulary exclamation and ambiguous rising-statement questions. Both are semantic and
zero-sum for rules: ranking `!` second helps one class by hurting the other. That headroom belongs
to a small on-device classifier, not to more rules.

**Known blind spots, accepted:** generated sentences skew US-English texting idiom, there is no
emoji handling, no conversation-history context, and the annotators are LLMs rather than the real
user population.

One protocol note worth stating, because it invalidates naive runs: `UITextChecker` rankings adapt
to text already typed. An XCUITest session shifted typo miscorrections from 4 to 18 on a rerun.
Checker-dependent benchmarks run solo after `eval/v4/reset-lexicon.sh <udid>`, never alongside
another `xcodebuild` session.

## Run it

Engine tests need no Xcode:

```
cd engine && swift test
```

One suite:

```
cd engine && swift test --filter BlindCorpusAccuracyTests
```

The Xcode project is generated with XcodeGen from `app/project.yml`. See
`docs/runbooks/build-and-eval.md`.

## Layout

```
engine/     Swift package: rules, cycling, ranking, capture. No dependencies.
app/        Xcode host app + UIKit keyboard extension.
eval/       Corpora, annotation protocol, assembly scripts, contamination reports.
docs/       Architecture, conventions, runbooks, decisions.
specs/      Per-change specs.
EVAL.md     The benchmark charter and current scores.
PRODUCT.md  What it is and why.
```
