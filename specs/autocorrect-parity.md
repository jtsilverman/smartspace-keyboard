---
status: active
---
# Autocorrect parity

Serves `specs/vision.md`. Every check below cites the vision milestone it serves.

## Intent

Autocorrect must behave the way Apple's keyboard behaves, judged against Apple's own
output rather than against our taste. Today every correction comes from
`UITextChecker`, the public spell-check API that draws red squiggles in Mail. It sees
one word at a time, returns guesses alphabetically, and knows nothing about where the
thumb landed or what the sentence says. Apple's keyboard runs a private on-device
system that reads sentence context and splits a run-together word into two. Jake
asked for that behavior in all aspects (2026-08-19), so this spec builds our own
correction engine and gates it on agreement with the stock keyboard.

Names carry their own weight (Jake, 2026-08-19). A name the engine mangles is the
most expensive miscorrection there is, and stock also fixes a name toward the spelling
in your contacts. Both directions are gated: the frozen protection corpus already
holds 25 name rows and 20 brand rows and scores 100/97, and that score is a floor no
unit may drop.

The move that makes "as close to Apple's as possible" checkable: we already drive the
real stock keyboard in the simulator through XCUITest (`BoundaryProbeTests`,
`EdgeSweepTests`, `CoverageProofTests`, all landed 2026-08-18). The same harness can
type a corpus of keystrokes into stock and record what stock produced. Apple's own
answers become the gold labels. Every gate in this spec is a percentage of rows where
we produce what stock produced.

## Non-goals

- Languages other than en-US.
- Swipe or glide typing.
- Grammar correction. Harper (Apache-2.0, Rust) has never run on iOS and skews toward
  spelling; LanguageTool needs a server, and Apple's own LanguageTool app sends text
  off device. Their/there and subject-verb agreement stay out.
- Personal adaptation of autocorrect to Jake's typing. Vision milestone 4 covers
  personal style for the punctuation engine only. Autocorrect adaptation waits until
  the stock-agreement number is stable.
- Emoji prediction.
- Replacing `UILexicon` as the source of contacts and text replacements. The engine
  keeps reading it. Correcting a mistyped name toward a contact's spelling is in
  scope, and it reads that spelling from `UILexicon`.
- The visible layer. No key geometry, hit area, colour, or bar layout changes.

## Orientation

**What exists today.** The correction path is four parts:

| Part | File | Owns |
|---|---|---|
| Candidate source | `app/Shared/SystemSpellChecker.swift` | `UITextChecker.guesses` and `.completions`, the entire vocabulary |
| Decision | `engine/Sources/TypingEngine/CorrectionEngine.swift` | Re-ranking by Damerau distance then `WordRank` frequency, and every never-correct guard |
| Bar orchestration | `engine/Sources/TypingEngine/AutocorrectController.swift` | What the three slots show, undo, protection |
| Prediction | `engine/Sources/TypingEngine/NextWordPredictor.swift` | A hand-built bigram table and three fixed trios |

**What is non-obvious.**

- `CorrectionEngine` never sees the sentence. `decision(for context:)` takes the full
  text but uses it only to find the last word and to test for a sentence start.
- Tap coordinates die inside `KeyTouchSurface`. `BiasedKeyResolver` turns a point into
  one letter and the point is discarded, so no downstream part can reconsider it. The
  language prior in that resolver is off since 2026-08-18: stock's boundaries measured
  as uniform geometry, and our bigram table pulled against them.
- `WordRank` already ships 20k frequency-ranked words generated from Norvig's
  `count_1w.txt` (public domain). That file is the seed of our own dictionary.
- Every guard in `CorrectionEngine` exists because a blind corpus caught a
  miscorrection. Guards are cheap to keep and expensive to rediscover; the new engine
  inherits them rather than starting clean.
- The keyboard extension's memory ceiling is roughly 60MB before iOS kills it. One
  shipping keyboard measured 63 to 70MB before optimising, dropping to 27MB by
  memory-mapping the word list instead of holding it on the heap.

**Research, 2026-08-19** (5-axis deep research, this session). Licences that matter:

| Component | Licence | Use |
|---|---|---|
| AOSP LatinIME native engine | Apache-2.0 | Port. The only permissive engine that does context and space correction |
| OpenBoard | GPL-3.0 | Excluded |
| FUTO android-keyboard | Source First, non-commercial | Excluded. Its trie-plus-transformer shape is the blueprint we copy, not the code |
| SymSpell | MIT | Reimplement in Swift if the trie underperforms |
| Hunspell / Nuspell | LGPL, some dictionaries GPL-only | Excluded. The dictionary licences are the trap, not the engine |
| Apple QuickType | Private | 34M-parameter GPT-2-style model in Core ML. Evidence that the size is feasible, not a component |

Gboard's shipping neural next-word model is 1.4MB after quantisation, so model size is
not the constraint.

**Brain.** `wiki/patterns/ios-xcode-swift.md` is the only relevant page: XCUITest
placeholder `.value` reads, the 40-minute UI-suite cap, and simulator fidelity gaps.
The 40-minute cap governs the oracle harness, which must run in slices.

## Decomposition

Unit 0 is the gate for every unit after it. Units 1 and 2 build the substrate. Units 3
and 4 depend on unit 1. Unit 5 runs alongside from unit 1 onward.

**0. The stock oracle.**
A corpus of keystroke sequences and a harness that types each one into the real stock
keyboard and records stock's output. Sliced to stay under the 40-minute XCUITest cap,
resumable, and frozen once recorded. Produces `eval/oracle/stock-<date>.tsv`: the
keystrokes, what stock produced, and the device and iOS version that produced it.

The corpus carries four named slices, blind-authored to the project's existing charter
(`eval/v4/`), each sized so a slice fits one XCUITest run:

| Slice | Rows | Holds |
|---|---|---|
| `sloppy` | 150 | Words typed with the thumb off-centre, generated from real key geometry |
| `nospace` | 100 | Run-together tokens and tokens broken by a stray space |
| `context` | 100 | The same typed token in two different sentences, 50 pairs |
| `names` | 50 | Contact and brand names, typed clean and typed with one slip |

Recording is not the same as ground truth. Stock's engine adapts: this project already
measured `UITextChecker` miscorrections shifting from 4 to 18 across reruns
(`docs/conventions/code-and-tests.md`). Unit 0 therefore holds back a 30-row drift
slice, re-records it after a full day of unrelated simulator sessions, and compares.
If stock's answers drift, the oracle is not ground truth and this spec's gating
strategy fails; that outcome stops the loop and reopens vision milestone 5 with Jake
rather than being worked around.

**1. Our own dictionary.**
A frequency-ranked word list in the engine, seeded from the existing `WordRank` source
and widened, held in a trie ported from LatinIME's binary dictionary shape and
memory-mapped rather than heap-resident. `SpellChecking` keeps its seam;
`SystemSpellChecker` becomes one implementation and the new dictionary becomes the
default. Every existing guard in `CorrectionEngine` survives.

**2. Touch points reach the corrector.**
`KeyTouchSurface` records the tap coordinates for the word being typed and hands the
sequence to the corrector alongside the letters. Candidate scoring weighs each
letter's distance to the tapped point, which is what LatinIME's ProximityInfo does.
The `BiasedKeyResolver` geometry stays the source of the committed letter, so key
areas do not move and the muscle-memory invariant holds.

**3. Missed spaces.**
Split a run-together token into two dictionary words, and join a token broken by a
stray space. Both scored against the oracle.

**4. Sentence context.**
Two stages, both behind one interface so the second replaces the first without
touching callers.
  - 4a: a word-pair table re-ranks the candidate list by the preceding word.
  - 4b: a small transformer, trained by us, compiled to Core ML, re-ranks the same
    list. Training data comes from a public English corpus with synthetic typos
    generated by the unit-2 touch model, because no keystroke corpus of Jake's typing
    exists.

**5. Memory and numbers.**
A measured resident-memory figure for the extension on device, and the agreement
number against the oracle reported per unit.

## Creativity beat

**Alternative A, rejected: keep `UITextChecker` and add context on top.** Cheapest,
and it fails on the two things Jake named. The checker cannot propose "hello world"
for "helloworld" at all, so missed spaces stay impossible however good the re-ranking.

**Alternative B, rejected: buy KeyboardKit Pro.** A commercial binary with a local
autocomplete engine built for iOS keyboard extensions. Rejected because its engine
internals are undisclosed, so we cannot measure it against the oracle or fix a
miscorrection Jake reports.

**The 10x version, folded in as unit 4b:** train the model on Jake's own typing so the
engine learns his hands. Deferred by the non-goals until the stock-agreement number is
stable, because a model that adapts to a weak baseline learns the wrong thing.

**The simplest form that works:** units 0, 1 and 3. Our own dictionary plus missed
spaces, no touch model and no context, gated on the oracle. That combination already
fixes the two failures Jake named.

It is not a licence to stop. Every check below is unconditional. A unit that stalls
stops the loop and reopens vision milestone 5 with Jake, who decides whether to drop
the unit and rewrite the check or to keep pushing. A loop that quietly declares
victory on the subset is the failure this paragraph exists to prevent.

## GOAL

Jake types on SmartSpace and it feels like he is typing on the Apple keyboard when it
comes to autocorrect (his words, 2026-08-19). Sloppy thumbs land on the word stock
lands on. A message typed with the spaces missing comes back as words. The same typo
in two different sentences corrects two different ways, because the engine reads the
sentence before it. Names survive, and a mistyped name lands on the contact's
spelling. Jake types twenty real messages on stock and twenty on SmartSpace and counts
the ones he had to fix by hand; the counts match.

## CHECKS

Derived, not Jake-facing. Each check cites the vision milestone it serves.

1. **vision:1,5** -- the stock oracle exists, is frozen, and is proven stable.
   `eval/oracle/stock-*.tsv` holds the four named slices, 400 rows, each with stock's
   own output, the recording device and the iOS version. The 30-row drift slice
   re-records after a full day of unrelated simulator sessions and reproduces its
   recorded output. A drift slice that does not reproduce fails this check and stops
   the loop.
2. **vision:5** -- our dictionary replaces `UITextChecker` as the candidate source, the
   frozen 320-pair typo bench holds at or above 90% corrected with at most 23
   miscorrections (`EVAL.md`, the current number after the distance-guard trade, not
   the 30 of the original baseline), and the frozen protection corpus holds at or
   above 100/97 with its 25 name rows and 20 brand rows all passing.
   `TypoBenchmarkTests` prints those numbers today and asserts only that the counts
   sum; unit 1 adds the threshold assertions, so the check can fail.
   `xcodebuild test -only-testing:SmartSpaceTests/TypoBenchmarkTests` and the protect
   set from `KeyboardEvalV4Tests`.
3. **vision:1,5** -- with touch points feeding the corrector, agreement with the
   oracle on the sloppy-typing slice beats the agreement measured for the current
   engine on the same slice. Both numbers printed by the oracle comparison test.
4. **vision:5** -- on the missed-space slice, the engine splits and joins at an
   agreement with the oracle at or above the number unit 0 measures for stock's own
   repeat run, and the count of rows in that slice is asserted, not sampled.
5. **vision:5** -- context re-ranking changes the winner: a corpus row where the same
   typed token corrects two ways in two sentences passes, and overall oracle agreement
   rises against unit 3's number.
6. **vision:1** -- the extension's resident memory stays under 55MB with the
   dictionary and the Core ML model loaded, measured on device and recorded in
   `EVAL.md`.
7. **vision:1** -- the visible layer and the hit map are untouched. `swift test` is
   green at or above 401 tests, `StockBoundaryTests` passes unchanged, and
   `eval/parity/run-parity.sh` reproduces the numbers recorded in `EVAL.md` under
   "Stock design parity, measured from screenshots" (2026-08-19: worst cap delta
   0.33pt, 2.77% of key-area pixels differing).

## LOOP

/loop Read specs/vision.md, then specs/autocorrect-parity.md. Work on branch feat/autocorrect-parity. Close the next open check in the CHECKS block, commit it with the evidence in the message, and report which vision milestones are satisfied.
STOP when every check is true, the named check commands pass, and `agents/vision-auditor.md` returns MATCHES on every in-scope milestone.

## Decisions

| Decision | Reason |
|---|---|
| Gate on agreement with the stock keyboard, not on a corpus we label | Jake asked for Apple's behavior in all aspects; the XCUITest harness that drives stock already exists |
| Port AOSP LatinIME rather than SymSpell or Hunspell | Apache-2.0, and it is the only permissive engine that already does context and space correction |
| Keep every guard in `CorrectionEngine` | Each guard traces to a miscorrection a blind corpus caught |
| Memory-map the dictionary | A shipping keyboard measured 63 to 70MB heap-resident, 27MB memory-mapped |
| Train on a public corpus with synthetic typos from the touch model | No keystroke corpus of Jake's typing exists |
| Personal adaptation deferred | A model that adapts to a weak baseline learns the wrong thing |
| The oracle carries a drift slice | `UITextChecker` miscorrections already shifted 4 to 18 across reruns on this project; stock's engine adapts harder |
| Names gated in both directions | A mangled name is the most expensive miscorrection; stock also fixes a name toward the contact spelling (Jake, 2026-08-19) |

## Progress

- [ ] 0 stock oracle
- [ ] 1 our own dictionary
- [ ] 2 touch points reach the corrector
- [ ] 3 missed spaces
- [ ] 4a word-pair context
- [ ] 4b trained model in Core ML
- [ ] 5 memory and numbers
