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

**Checker-state protocol:** UITextChecker rankings adapt to typed text -- an XCUITest session shifted typo miscorrections 4 -> 18 on rerun. The checker-dependent suites (the scenario corpus, `SystemSpellCheckerTests`) run SOLO after `eval/v4/reset-keyboard-state.sh <udid>`, never alongside another xcodebuild session. The protect, typo and completion benches score the engine's own dictionary and run under `swift test` (2026-09-12).

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

## Agreement with the stock recording (2026-08-20)

`OracleAgreementTests` types all 400 frozen rows through our engine and compares
what it produced with what the real stock keyboard produced. Runs under
`swift test`, because our candidate source is pure Swift. Case and apostrophe
style are normalized away; those belong to the autocap and smart-punctuation
rules, not to the correction.

| Slice | Agreement |
|---|---|
| sloppy | 150/150 (100%) |
| names | 43/50 (86%) |
| context | 69/100 (69%) |
| nospace | 53/100 (53%) |
| **total** | **315/400 (78%)** |

The sloppy slice already agrees on every row, so check 3 has no headroom left to
measure on it: the touch model cannot raise 100%. The missed-space slice is the
weakest, and it is the one waiting on the word-pair model of unit 4a.

These are agreement with a recording. The drift gate failed on 2026-08-20, so a
row we disagree on is a lead, never a verdict.

**The names slice is a dictionary gap, not a rule gap.** Stock left `nathen`,
`jesica` and `danial` alone and we corrected them, which reads at first like a
missing confidence rule. Requiring the edit to be an adjacent-key swap before a
correction may reach a name took the slice from 43/50 down to 32/50, because
stock does fix `sarha` to `Sarah` and `emliy` to `Emily`, both transpositions.
What separates the two groups is that `Nathen`, `Jesica` and `Danial` are real
name spellings, and the 2014 AOSP list does not carry them. `Venmo` is the same
story. A wider name list closes these; a rule cannot.

## One-key slips, and the student pilot (autocorrect-loop, 2026-09-12)

`eval/slips/gen_slips.py` writes every single slip of the 3,000 commonest words from
the stock key geometry: 158,251 rows of five kinds. `SlipBenchTests` types every
256th row in the suite and all of them with `SLIP_BENCH_ROWS=all` (release build,
175s): corrected 135,730/158,251 (85%), miscorrected 17,032. Per kind: double 96%,
swap 94%, neighbor 93%, drop 86%, split 23% (8,664 miscorrected).

A 150-row kind-stratified sample was recorded from stock and joins the oracle as
the `slips` slice: agreement 110/150. double 29/30, swap 28/30, neighbor 25/30,
drop 15/30, split 13/30. The drop and split kinds are the work list.

The student (`ContextModel`, 1.74M parameters, LSTM 384 over a 10k word vocabulary,
3.4MB float16 mapped) was trained on 16,926 sentences (NUS SMS plus the first
teacher text) to dev perplexity 132. Behind `ContextScoring` it ties the pair table
on the pilot: context/dev 35/50 and nospace/dev 32/50 for both, with 2 of the 200
rows deciding differently. The model reaches only distance ties and split
decisions; most context misses are stock leaving a typo alone.

Rerun 2026-09-13 on 216,928 sentences (NUS plus 200k teacher messages, four
epochs, 117s an epoch on the mini): dev perplexity 53.1. The pilot still ties,
35/50 and 32/50 for both models. The unit stopped and reopened with Jake: the
seam, not the model, is the limit.

## Missed spaces: what stock splits, and what we can (unit 3)

Read off the 50 recorded missing-space rows. Stock split 48, and every split it
made had both halves common: the weakest half scored 90 on the AOSP 0-255
frequency scale. It refused `amin` rather than offer `am in`.

Scoring a split below a one-edit substitution, which is what stock does
(`onmy` -> `on my` over `only`), costs 8 points of the typo bench and takes
miscorrections from 17 to 41. The winners become `din net` for `dinnet`, `go ID`
for `goid`, `GT eat` for `gteat`, `SB out` for `sbout`.

Frequency cannot separate those from the real splits. `din` scores 94, and
`woke`, `parked` and `thank` score 90, 99 and 100. What separates them is
whether the two words go together, which is the word-pair model of unit 4a.

Ours therefore splits conservatively: only when no single word sits one edit
away, only when one half is four letters or more, and never when a half is
capitalized. Without those last two, `badass` became `bad ass` and `Kaius`
became `Kai us`, which the protection corpus gates on. `thankyou` -> `thank you`
lands; `onmy` -> `on my` waits for 4a.

## The word before the typo (unit 4a, 2026-09-11)

`WordPairs` is Norvig's `count_2w.txt` (web bigrams, `engine/tools/vendor/NOTICE`)
kept where both words are in `WordRank` and the count reaches 300,000: 90,310
pairs. `CorrectionEngine` breaks a distance tie on the pair count before word
frequency (`more thn` -> `than`, `and thn` -> `then`), and a split whose halves
are a pair costs 0.9 against a one-edit word, so `onmy` -> `on my` and
`melater` -> `me later` land. An unbacked split of two short words is no
candidate at all, which is what keeps `badass` whole: `bad ass` sits at 204,647
in the source, and the floor was set above it and below `breakfast is` at
346,954, the weakest split stock made that the counts hold. `a jacket` at
228,568 is the one recorded split that trade loses.

| Slice | Before | After |
|---|---|---|
| sloppy | 150/150 | 150/150 |
| names | 43/50 | 43/50 |
| context | 69/100 | 69/100 |
| nospace | 53/100 | 64/100 |
| **total** | **315/400 (78%)** | **326/400 (81%)** |

The context slice did not move. Its misses are stock refusing corrections we
make (`hav`, `sen`, `liv`, `ther`, `thier`, `definately` all left alone by
stock), plus `salt nad pepper` and `alot`, where the typed token is a word our
list holds (`nad`, `alot`) so no candidate is ever offered. Correcting a known
word on context is what stock does (`hom` -> `him`) and is not in the pair
table's reach. The remaining nospace misses are stray-space joins (`tomo rrow`),
which are not attempted, and rows where stock's own answer is noise (`than ks`
-> `Than is`, `ba ck` -> `ba close`).

Frozen benches, simulator, state reset first: protection 100 dev / 96 test
(unchanged), completions 95 / 97 (unchanged), typos 91% with 18 miscorrections
(was 92% / 17). The one new miscorrection is `allready` -> `all ready`, a
backed split beating a one-letter deletion. Scoring an extra doubled letter as
half an edit, the mirror of the `realy` -> `really` rule, fixed that row and
broke `sprry` -> `sorry` into `spry`, so the model stays as is
(`brain/traces/2026-09-11-a-symmetric-looking-typo-rule-was-not-symmetric.md`).
`allready` is a lead for the trained model of unit 4b: nothing follows `I'm`
in the pair table, because the source splits contractions into two tokens.

## Stray spaces: two fragments come back as one word (2026-09-11)

Read off the 50 recorded stray-space rows. Stock joined 9: every one where
both halves are unknown and two letters or more (`tomo rrow`, `cor ner`,
`fli ght`, `rea dy`, `leav ing`) plus four with a known half (`meet ing`,
`ear ly`, `wor ks`, `asle ep`); it left every pair with a one-letter half
(`g o`, `u p`, `d ay`) and every other known-half pair (`com ing`, `id ea`,
`sec ond`), and mangled 13 (`ba ck` -> `ba close`, `li nk` -> `li no`, `than
ks` -> `Than is`). Ours joins two unknown halves of two letters or more. That
takes the five clean rows and loses `ga te` (stock left it), and produces
`back`, `link`, `landed`, `closes` on rows where the recording is noise.

The first fragment is corrected at its own space (`tomo` -> `too`), so the join
revises the last correction: the session remembers both sides and the join
takes `too rrow` out of the field while an undo restores `tomo rrow`.

nospace 63 -> 68/100, total 329 -> 333/400. Benches unchanged to the miss line.
What is left in the slice, 32 rows: 13 where stock's answer is noise, 4 where a
known half is the fragment (`meet ing`), and the rest where a known token our
list holds blocks a split (`mein`, `isa`, `timeworks`, `iam`) or the pair is
below the table's floor (`i fell`, `time works`).

## Names: the list carries US first names (2026-09-11)

The names gap named on 2026-08-20 closes by vocabulary. Every name from the
Social Security Administration's top-1000 tables that the AOSP list lacks
(2,961) lands after the texting lexicon. Names slice 43 -> 46/50, total
326 -> 329/400, benches unchanged to the miss line. What is left in the slice:
`venmo` -> `venom` and `airbnd` -> `airbed` (post-2014 brands the list lacks; a
sourced brand list is the fix) and `jaje` -> `Jane` where stock said `Jake`
(the user's contact, which reaches the engine through UILexicon on the device
and not in this test).

The trade the names carry: 65 of the added names are three letters or fewer
(Sid, Les, Ian, Eli, Bo, Isa, Al among them) and each is one edit from a common
word, so `sid` no longer corrects to `said` and `les` no longer to `less`. The
typo bench holds no such row. Kept as is: a typed name the engine mangles is the
costlier failure, and stock keeps a name it knows. A probe slice of these shapes
against stock is the evidence that settles it; recorded here as a lead.

## Memory: the word tables are mapped, not held (2026-09-11)

Physical footprint of the keyboard extension in the iPhone 17 Pro simulator with
the keyboard up and a correction applied (`footprint -p`, sampled every 5s while
`MissedSpaceLiveTests` drives it):

| Tables | Steady | Peak | MALLOC_LARGE |
|---|---|---|---|
| Swift dictionaries built from string literals | 70MB | 78MB | 19MB |
| Memory-mapped binary files (`Resources/*.bin`) | 42MB | 43MB | 304KB |

The ceiling is 55MB (check 6). The simulator is a proxy: the on-device number is
owed. In the engine test process, loading both tables grows the heap 150KB
(`WordTableMemoryTests`), from 23MB.

## What stock's autocorrect actually keys on (probes, 2026-08-20)

Two probe sets were typed into the stock keyboard through the XCUITest harness.
The alphabet sweep holds a word and a slot fixed and puts all 25 other letters
through it, inside the carrier `i said X to him`, so siblings differ by one
letter and nothing else. 150 rows over `water`, `phone`, `night`, `house`,
`money`, `check`.

**Distance from the right key does not predict what stock does.** Counting only
slips that produced a non-word:

| Wrong key sits | Fixed | Corrected to another word | Left alone |
|---|---|---|---|
| Next to the right one | 14 | 1 | 10 |
| Two or three keys away | 22 | 9 | 20 |
| Far across the keyboard | 26 | 8 | 21 |

Every row sits one letter from a common word, so a close candidate always
existed. The fix rate is flat at 56%, 43% and 47%.

**The sloppy slice says the opposite, and that is the finding.** Those 150 rows
tapped real coordinates off the key centre, and 61 of their taps landed past a
boundary onto the neighbouring key. Stock recovered the intended phrase in every
one. Clean centre taps on a wrong key: 47% recovered. Off-centre taps that
produced a wrong letter: 100% recovered.

Stock's slip detection reads where the thumb landed, not which letter came out.
A dead-centre press of the wrong key is a deliberate keystroke to it, and it
corrects that only when the language model is confident on its own. That is why
letter-level key adjacency cannot replicate it, and it is what unit 2 of
`specs/autocorrect-parity.md` builds.

Where stock did pick another word, it picked the nearest one: `waber` ->
`waver`, `waier` -> `waiter`, `wamer` -> `warmer`, `ninht` -> `ninth`.

Slip shapes, from the 181 carrier probes, all with clean taps:

| Shape | Fixed |
|---|---|
| One neighbour swap | 9/10 |
| Deleted letter | 6/10 |
| Doubled letter | 3/10 |
| Transposition | 1/9 |
| Two slips in one word | 0/10 |

Word length changes nothing (4/4 at three, five and eight letters). Autocap
protects hard: the same probes typed alone, where autocap capitalizes them,
came back untouched (`helllo`, `Josue` for `hosue`).

## Our own dictionary against UITextChecker (unit 1, in progress)

`DictionarySpellChecker` scans the engine's own word list within an edit budget.
Two word lists were measured on the frozen benches, both through the same
`CorrectionEngine` with every guard intact. iPhone 17 Pro, iOS 26.3, 2026-08-19.

| Bench | UITextChecker | Norvig + Webster, 15,328 words | AOSP LatinIME, 165,804 words | AOSP plus the confidence rule | Check 2 gate |
|---|---|---|---|---|---|
| v3 typos corrected | 90% | 93% | 92% | 92% | at or above 90% |
| v3 typo miscorrections | 23 | 16 | 17 | 17 | at most 23 |
| v4 typos corrected | 89% | 90% | 87% | 89% | not gated |
| Protection, dev | 100 | 98 | 95 | **100** | at or above 100 |
| Protection, test | 97 | 94 | 94 | 96 | at or above 97 |
| Completions, dev / test | 91 / 95 | 91 / 91 | 95 / 97 | 95 / 97 | not gated |

The bigger list wins on completions and loses on protection. Every protection
loss is a name the engine corrects toward a near neighbour it now knows:
`Kaius` -> `Kai's`, `Anaya` -> `Anya`, `Giannis` -> `Gianni`, `Kylian` ->
`Kalian`, `Jaxon` -> `Jason`, `Malia` -> `Maria`, `Dakari` -> `Dakar`. A wider
vocabulary supplies more plausible wrong candidates, so vocabulary size alone
cannot close check 2.

The oracle says stock does not behave this way: `michal` stayed `Michal` and
`jesica` stayed `Jesica`. Stock leaves a name-shaped unknown alone rather than
moving it to the nearest name.

**The confidence rule** closed the gap without costing a typo fix. A capitalized
word the list does not know keeps its spelling when the best candidate is either
a proper noun in its own right, or a swap for a key that is not next to the one
typed. `KeyNeighbors` derives which keys touch from the same measured stock
geometry the keyboard draws, so `Kylian` -> `Kalian` is refused because `y` and
`a` sit at opposite ends of the keyboard. Every name and brand row now passes on
both halves, and protection dev is back at 100.

Protection test sits at 96 against a 97 gate, one row short of 93/95. That row
is in the held-out half and stays unstudied.

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

**The drift gate failed.** The 30 held-back rows were re-typed on 2026-08-20,
once with the learned keyboard state intact and once from a cleared dynamic
lexicon. Both runs reproduced 28 of 30 and both moved the same two rows:

| Row | Recorded 2026-08-19 | Both runs, 2026-08-20 |
|---|---|---|
| `tell im i said hi` | `Tell im I said hi` | `Tell I'm I said hi` |
| `the delay occured again` | `The delay occured again` | `The delay occurred again` |

Clearing the lexicon did not restore the recorded answers, so the change does
not live in the state `eval/v4/reset-keyboard-state.sh` clears. Stock's answers
moved over time and stayed moved. Two rows in thirty is a 6.7% instability, and
the recorded file holds 400 rows.

Superseded below: the original drift-gate note. Check 1 also requires the 30-row held-back slice
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

Re-run 2026-08-20, after the dictionary, the confidence rules and the touch
wiring landed: `pct_pixels_differing` 2.77 on iPhone 17, the same number to two
decimals. The engine work moved no pixels, which is check 7's clause and the
invariant that outranks every score in this file.

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
