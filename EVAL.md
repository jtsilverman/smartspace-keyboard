# Eval Charter (v3)

The benchmark every engine change (rules today, model later) is judged against. Two principles rule everything (Jake, 2026-07-27): **wide, not deep** -- many varied scenarios over many variations of one scenario -- and **independent of the code** -- no corpus row may be authored, labeled, or edited by anything that has seen the engine source. Rule improvement is invariant-first: cluster dev misses by scenario type, name the invariant, write the general rule; never one patch per sentence.

## Marks in scope

- `.` `?` `!` `,` `"` -- the four texting workhorses plus the opening quote. Comma is "the sentence continues here"; the opening quote is "quoted speech starts here" -- both continuation predictions, structurally different from sentence enders (Jake, 2026-07-26).
- Deferred (`: ; -`): rare in texting; each extra cycle candidate slows recovery. Revisit if opt-in export data shows real usage (Jake, 2026-07-26).

## Sets

- **Blind benchmark** (`BlindCorpus.swift`, 1,196 rows) -- **the headline number.** Sentences authored by fresh-context generators (no repo access) across a taxonomy: 18 scenario forms x 3 registers (full / txt / frag) x mixed lengths. Gold = majority of 3 independent annotators labeling in shuffled order with no engine knowledge and no sight of generator intent. Generation + annotation protocol and QC live in `eval/` (raw pool, per-annotator votes, assembly script, contamination report). Label-stratified dev/test split (598/598).
- **Real-SMS v3** (`RealCorpusV3.swift`, 638 rows) -- the reality check. Same UCI sentences as v2.1; gold relabeled by majority of 3 blind annotators (3-way splits keep the sender label; 270/638 sender labels were overturned -- one keystroke is not gold). Split membership preserved.
- **Real-SMS v2.1** (`RealCorpus.swift`) -- retired from reporting, kept untouched as provenance.
- **Rule-regression suite** (`Corpus.swift`) -- NOT a benchmark. Written with knowledge of the rules, roughly one row per rule branch; catches a broken rule, never a missing one. Keeps its hard gates (top-1 >= 90%, top-2 >= 97%) as tripwires.
- **Typo corpus** (`eval/raw/typo-pairs.tsv`, 320 pairs) -- autocorrect benchmark: blind-generated typo -> intended pairs across 5 error categories; scored against the real `UITextChecker` through the CorrectionEngine pipeline in the simulator test target (`app/SmartSpaceTests`). Metrics: corrected / left-alone / miscorrected; miscorrection is the expensive failure. Baseline 2026-07-27: 90% corrected, 30/320 miscorrected, 2 missed; transposition 60/60, doubled-letter weakest (30/40).
- **Future**: opt-in export data becomes new frozen real sets (and ML training data -- training rows and eval rows never overlap).

## Rules of the game

- Dev misses may be studied; the test half reports aggregate numbers only, its sentences are never inspected.
- FROZEN: benchmark rows never change in a commit that also touches engine source. Regeneration/expansion is its own commit.
- Annotation inputs are always SHUFFLED: the ordered-input first pass produced block-stamping annotators (archived in `eval/raw/`); randomized order is what made votes independent.
- Reported per label AND per scenario form (aggregate only for test halves) -- misses cluster by invariant, and a change that lifts one mark by tanking another stays visible.

## Metrics + scores

Top-1 = right on the first guess. Top-2 = right within one cycle tap (the product-truth metric).

- Baseline (2026-07-27, rules unchanged from 1.9): blind dev 50/62, test 48/63; real-v3 dev 73/91, test 67/85.
- After the rules-invariants pass (2026-07-27): blind dev 68/81, **test 61/76** (+13/+13 held out -- generalized, not dev-fit); real-v3 dev 72/92, **test 65/84**. Per-form dev: quote-introducer 13->75, comma-conjunction 5->95, comma-vocative 4->84, greeting 50->73/93, urgent 12->31/37, exclamation 6->33/40.
- Ship gate (spec AC 7c, Jake 2026-07-27): top-2 >= 80% blind test AND top-2 >= 85% real-v3 test. NOT YET MET (76 / 84). The remaining gap is open-vocabulary exclamation and ambiguous rising-statement questions -- semantic, zero-sum for rules (ranking ! second helps one class by hurting the other). This is the spec's documented rules-plateau trigger: remaining headroom belongs to the tiny on-device classifier (~1-5MB, Gboard precedent).

## Known blind spots (accepted)

Generated sentences skew US-English texting idiom; 2000s UK/Singapore idiom lives only in the real set; no emoji; no conversation-history context; annotators are LLMs, not the actual user population (export data eventually corrects this).

## Keyboard-wide eval v4 (2026-07-28, specs/keyboard-eval.md)

Extends the suite beyond punctuation+typos to every keyboard behavior: capitalization (92 rows), contractions/smart symbols (179), autocorrect protection (196), casual typos (114), completions (93), e2e keystroke scenarios (40). Same charter: blind-authored (5 fresh-context generators, web-grounded), blind-QC'd (27% cut rate), crc32-stratified dev/test split for the four split sets; typos and scenarios report whole-set. Frozen TSVs + assembly in `eval/v4/`; compiled corpora generated by `eval/v4/gen-corpus.py`.

**Checker-state protocol:** UITextChecker rankings adapt to typed text -- an XCUITest session shifted typo miscorrections 4 -> 18 on rerun. Checker-dependent benchmarks (protect/typos/completions/scenarios) run SOLO after `eval/v4/reset-lexicon.sh <udid>`, never alongside another xcodebuild session.

Scores (dev / test, top-line = row-level pass). Final = 2026-07-29 Pareto frontier:

| set | baseline | final |
|---|---|---|
| cap | 90 / 87 | 94 / 92 |
| symbols | 70 / 75 | 94 / 89 |
| protect | 77 / 75 | **100 / 97** |
| typos v4 | 92 whole-set (mis 4) | 89 (mis 3) |
| completions | 82 / 89 | 91 / 95 |
| scenarios (whole-set) | ~52 (14/27 observed) | **92 (36/39)**, 1 {RET} skip |

Overfit guard held: blind v3 test 61/76 unchanged throughout; real-v3 test 65/84 -> 67/85; frozen v3 typo bench 90% corrected with miscorrections down 30 -> 23.

Distance-guard trade (accepted): rejecting checker suggestions past Damerau max(1, len/4) converts protection miscorrections (expensive: mangles intended text) into a few missed typo fixes (cheap: word stays as typed). Remaining protect misses were distance-1 checker guesses (sus->sis, imy->my) -- vocabulary, not distance; closed by the shipped TextingLexicon (331 words, blind-compiled from public glossaries, eval/v4/texting-lexicon-source.txt).

The e2e scenarios caught what no unit suite could: learned-state pollution (PersonalRanking lock-in -- five smoke-test ?->. cycles permanently demoted ? for every question; fixed by counting only deliberate cycles), the smart-period-after-abbreviation class (shift arm + proper-noun guard both re-derived "not a sentence end" from context after the user's explicit end-sentence gesture), and live-path integration gaps (greeting-prefixed questions, all-caps shouting, lowercase name/calendar capitalization, '90s elision direction).

Invariant fixes (each names a class, unit-tested in `EvalV4InvariantTests.swift` / `EvalV4PredictionInvariantTests.swift`): ellipsis/emoji sentence terminators; non-word bare contraction curation criterion; em-dash word/text-start guard (CLI flags stay); digit primes stay straight; ... -> ellipsis collapse; proper-noun guard with post-period sentence starts; <=2-letter shortform guard; 3+ letter-run elongation guard; @/# handle guard; Damerau distance guard; recased-suggestion priority (jake -> Jake); shipped TextingLexicon; lowercase-prefix proper-noun completion merge; greeting-prefixed questions; all-caps exclamation; smart period always terminal (1.4 criterion updated); sentence-start Ill/Id -> I'll/I'd; digit elision retro-fix ('90s); CalendarRule weekday/month capitalization; deliberate-only personal reranking; smart-mark shift arm.

**Accepted frontier** (improving any of these costs another set or needs the ML/architecture phase):
- Distance guard: 3-4 long-shot typo fixes (phonetic/casual d>=2 short words) traded for name/slang/loanword protection.
- Uncommitted final word ("Text me your adress", "coming saturday" with no trailing space): corrections fire on commit; retro-correct-on-send is an architecture change.
- Mid-sentence "ill" -> "I'll": needs next-word lookahead (delayed correction), ML-phase territory.
- Title-abbreviation autocap gold dispute (3 cap rows: engine capitalizes after "Mr." because a name follows; blind gold says nocap).
- Code-context detection (JSON/CLI straight quotes), single-quote elision vs quote at type time ('n' rock 'n' roll), text-start --- divider (aside chosen), one join-ambiguous authored row (sym-107).
- Completions: NONE-rows (short valid words get junk completions) and context-aware ranking need a frequency/context model.
- {RET} scenarios (2) need a multiline practice field (Phase 4 host-app work).

## Our own dictionary against UITextChecker (unit 1, in progress)

`DictionarySpellChecker` scans the engine's own word list within an edit budget.
Two word lists were measured on the frozen benches, both through the same
`CorrectionEngine` with every guard intact. iPhone 17 Pro, iOS 26.3, 2026-08-19.

| Bench | UITextChecker | Norvig + Webster, 15,328 words | AOSP LatinIME, 165,804 words | Check 2 gate |
|---|---|---|---|---|
| v3 typos corrected | 90% | 93% | 92% | at or above 90% |
| v3 typo miscorrections | 23 | 16 | 17 | at most 23 |
| v4 typos corrected | 89% | 90% | 87% | not gated |
| Protection, dev | 100 | 98 | 95 | at or above 100 |
| Protection, test | 97 | 94 | 94 | at or above 97 |
| Completions, dev / test | 91 / 95 | 91 / 91 | 95 / 97 | not gated |

The bigger list wins on completions and loses on protection. Every protection
loss is a name the engine corrects toward a near neighbour it now knows:
`Kaius` -> `Kai's`, `Anaya` -> `Anya`, `Giannis` -> `Gianni`, `Kylian` ->
`Kalian`, `Jaxon` -> `Jason`, `Malia` -> `Maria`, `Dakari` -> `Dakar`. A wider
vocabulary supplies more plausible wrong candidates, so vocabulary size alone
cannot close check 2.

The oracle says stock does not behave this way: `michal` stayed `Michal` and
`jesica` stayed `Jesica`. Stock leaves a name-shaped unknown alone rather than
moving it to the nearest name. The missing piece is a confidence rule, not more
words.

## The stock oracle, recorded from the stock keyboard

Apple's own answers to the frozen 400-row keystroke corpus
(`specs/autocorrect-parity.md` unit 0). `eval/oracle/record.py` types each row
into the real stock keyboard and records what stock produced. iPhone 17 Pro,
iOS 26.3, 2026-08-19, learned keyboard state reset before every slice.

| Slice | Rows | What stock did |
|---|---|---|
| sloppy | 150 | Recovered the intended phrase in 150 (145 verbatim, 5 more as `im` -> `I'm`) |
| nospace, missing space | 50 | Split the run-together token in 48 |
| nospace, stray space | 50 | Changed 22; `tomo rrow` -> `tomorrow`, but `than ks` -> `Than is` |
| context | 100 | Resolved the same typed token two different ways in 20 of the 50 pairs |
| names, typed clean | 25 | Left all 25 untouched |
| names, one slip | 25 | Changed 19; `jaje` -> `Jake`, `davod` -> `David`, `youtub` -> `YouTube` |

The sloppy slice is sloppy by geometry, not by spelling: 2.7% of its 2,270
letter taps land past a key boundary onto the neighbouring key, and 50 of the
150 rows carry at least one such tap. Stock recovered every one of them.

Stock does not fix everything, and the rows it left alone are gold labels too.
`michal` stayed `Michal`, `jesica` stayed `Jesica`, `detla` stayed `delta`, and
the stray-space join failed more often than it worked. A unit that "improves" on
those rows disagrees with the oracle and fails its check.

Not yet proven: the drift gate. Check 1 also requires the 30-row held-back slice
to re-record after a full day of unrelated simulator sessions and reproduce its
recorded output. That run cannot happen before 2026-08-20.

## Stock design parity, measured from screenshots

`eval/parity/run-parity.sh` captures the stock keyboard and SmartSpace on the same
simulator and diffs the key area. iPhone 17, iOS 26.3, light mode, 2026-08-19:

| Measure | Result |
|---|---|
| Letter cap position, worst | 0.33pt (one device pixel) |
| Letter cap size, worst | 0.33pt |
| Space bar position / width | 0.00pt / 0.33pt |
| Function key fill | 254,254,254 against stock's 255,255,255 |
| Key area pixels differing | 2.77%, at glyph edges and the emoji key |

Dark mode is not at parity and predates the 2026-08-19 work: function keys read
36,36,36 against stock's 61,61,61, caps sit up to 1.33pt off, 11.7% of pixels differ.
Measured with and without the backdrop change; both runs identical.

## Key coverage against stock

`CoverageProofTests` taps every point of every letter row in 1pt steps on both
keyboards and records what each point types. iPhone 17, iOS 26.3, 2026-08-19:

| Row | Points | Same letter as stock | Dead on stock | Dead on SmartSpace |
|---|---|---|---|---|
| qwertyuiop | 393 | 89.6% | 0 | 0 |
| asdfghjkl | 353 | 90.1% | 0 | 0 |
| zxcvbnm | 274 | 89.8% | 2 | 0 |

No point of the keyboard is dead. Every disagreement sits within 4pt of a key
boundary, where stock's own map flips back and forth between the two letters.
