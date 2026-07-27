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
- **Typo corpus** (`eval/raw/typo-pairs.tsv`, 320 pairs) -- autocorrect benchmark: blind-generated typo -> intended pairs across 5 error categories; scored against the real `UITextChecker` through the CorrectionEngine pipeline in the simulator test target (harness lands after the 3.1 scaffold merges). Metrics: corrected / left-alone / miscorrected; miscorrection is the expensive failure.
- **Future**: opt-in export data becomes new frozen real sets (and ML training data -- training rows and eval rows never overlap).

## Rules of the game

- Dev misses may be studied; the test half reports aggregate numbers only, its sentences are never inspected.
- FROZEN: benchmark rows never change in a commit that also touches engine source. Regeneration/expansion is its own commit.
- Annotation inputs are always SHUFFLED: the ordered-input first pass produced block-stamping annotators (archived in `eval/raw/`); randomized order is what made votes independent.
- Reported per label AND per scenario form (aggregate only for test halves) -- misses cluster by invariant, and a change that lifts one mark by tanking another stays visible.

## Metrics + baseline (2026-07-27, rules unchanged from 1.9)

Top-1 = right on the first guess. Top-2 = right within one cycle tap (the product-truth metric).

- Blind: dev 50% / 62%, test 48% / 63%. Strong forms: imperative 100, indirect-question 100, comma-conditional 96, wh-question 92. Weak forms (the invariant backlog): exclamation 15, quote-introducer 13, comma-vocative 4-14, comma-conjunction 5-10, urgent-imperative 14, elliptical-question 5 top-1 (but 100 top-2).
- Real-SMS v3: dev 73% / 91%, test 67% / 85% (was 47/41 on noisy v2.1 labels -- the old ceiling was label noise, not rule capability).
- Ship gate (spec AC 7c, Jake 2026-07-27): top-2 >= 80% blind test AND top-2 >= 85% real-v3 test.

## Known blind spots (accepted)

Generated sentences skew US-English texting idiom; 2000s UK/Singapore idiom lives only in the real set; no emoji; no conversation-history context; annotators are LLMs, not the actual user population (export data eventually corrects this).
