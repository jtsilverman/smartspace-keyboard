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

Scores (dev / test, top-line = row-level pass):

| set | baseline | after invariant pass |
|---|---|---|
| cap | 90 / 87 | 94 / 92 |
| symbols | 70 / 75 | 94 / 88 |
| protect | 77 / 75 | pending clean rerun |
| typos v4 | 92 whole-set | pending clean rerun |
| completions | 82 / 89 | pending clean rerun |
| scenarios | pending first run | -- |

Invariant fixes (each names a class, unit-tested in `EvalV4InvariantTests.swift`): ellipsis/emoji sentence terminators; non-word bare contraction curation criterion; em-dash word/text-start guard (CLI flags stay); digit primes stay straight; ... -> ellipsis collapse; proper-noun guard (capitalized mid-sentence, contraction included); <=2-letter shortform guard; 3+ letter-run elongation guard; @/# handle guard; lowercase-prefix proper-noun completion merge.

Accepted frontier (dev rows deliberately not chased): title-abbreviation autocap (gold disputes engine's Mr.-then-name behavior, 3 rows); code-context detection (JSON/CLI straight quotes, 1 row); single-quote elision vs nested-quote at type time ('n', 2 rows); text-start --- divider vs --aside (zero-sum, aside chosen, 1 row); one join-ambiguous authored row (sym-107).
