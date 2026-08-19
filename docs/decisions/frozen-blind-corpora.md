# Eval rows are authored blind and never move beside engine source

**Picked:** every benchmark row is authored, labeled, and QC'd by something that has never seen the
engine source. A benchmark row never changes in a commit that also touches engine source.

**Rejected:** writing eval cases from the rules, and editing a corpus row in the same pass that
changes a rule.

**Reason:** a corpus written against the rules can only catch a broken rule. It cannot catch a
missing one, and it cannot tell you the engine generalizes. Editing a row beside a rule change turns
a benchmark into a scoreboard the engine writes itself.

Two principles run the whole charter, both Jake's, 2026-07-27: **wide, not deep**, many varied
scenarios over many variations of one, and **independent of the code**.

**What this constrains:**

- **Dev is studied, test is not.** Dev misses may be inspected and clustered. The test half reports
  aggregate numbers only; its sentences are never read.
- **Annotation inputs are shuffled.** The first pass used ordered input and produced block-stamping
  annotators; those runs are archived in `eval/raw/`. Randomized order is what made the three votes
  independent.
- **Gold is a majority of three blind annotators.** Generator intent is metadata, not a vote. A
  three-way split goes to the ambiguity slice and scores top-2 only. On the real-SMS set, 270 of 638
  sender labels were overturned: one keystroke is not gold.
- **Regeneration is its own commit.** Never mixed with an engine change.
- **Report per label and per scenario form.** Misses cluster by invariant, and a change that lifts
  one mark by tanking another must stay visible.
- **Fix the invariant, not the sentence.** Cluster the dev misses, name the invariant, write the
  general rule. Never one patch per sentence.

**`Corpus.swift` is the exception that proves it.** It was written with knowledge of the rules,
roughly one row per branch. It is a regression tripwire, not a benchmark, and `EVAL.md` says so
explicitly. It keeps hard gates at top-1 90% and top-2 97%.

**The overfit guard works.** Across the 2026-07-29 v4 pass, blind v3 test held at 61/76 unchanged
while six other sets improved. That flatness is the evidence the gains generalized.

**A second contamination source the protocol had to catch.** `UITextChecker` rankings adapt to typed
text, and the extension's outcome log trains `PersonalRanking`. Five smoke-test question-to-period
cycles permanently demoted the question mark for every question. Checker-dependent benchmarks
therefore run solo after `eval/v4/reset-keyboard-state.sh <udid>`, which clears both the system
lexicon and the extension's `UserDefaults`.

**What would reopen it:** nothing about the blindness. The corpora themselves grow: opt-in export
data eventually becomes new frozen real sets, and training rows and eval rows never overlap.
