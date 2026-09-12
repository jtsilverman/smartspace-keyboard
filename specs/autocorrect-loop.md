---
status: active
---
# Autocorrect loop

Serves `specs/vision.md` milestone 5 (autocorrect judged against stock) and milestone 1
(nothing visible moves). Stacked on `specs/autocorrect-parity.md`: that spec's checks 2,
3 and 4 are the numbers this loop moves. Rewritten 2026-09-12 after Jake redirected it
from rule tuning to the two parts the engine lacks: a wide dictionary and a context
model.

## Intent

Two unattended loops, one judge. The first widens the dictionary and proves the
corrector on every slip a thumb can make. The second trains our own context model, the
transformer unit 4b of the parity spec, and pilots it before anything is committed to
it. Both run local models on the Mac Studio (M4 Max, 36 GB; Agnes is off as of
2026-09-12) rather than Haiku, by Jake's call 2026-09-12. Coverage is the goal of the
dictionary loop, quality the goal of the model pilot.

Jake's framing (2026-09-12): "try every type of fat thumb or finger slip or close
misspelling imaginable and that's how we determine the dictionary and the spell, name
correction engine"; and for the model, "distill or translate using the models
available into a customized version tuned to our purpose".

Research 2026-09-12 (`brain/sources/raw-research/2026-09-12-autocorrect-context-model-and-dictionary-research.md`)
fixed the routes:

| Question | Answer |
|---|---|
| Apple's on-device model (`FoundationModels`) | Unreachable from a keyboard extension without Full Access; the sandbox blocks the model daemon. Out |
| A pretrained model under 10 MB | None is both licensed and small; the 30k-token embedding table is the weight. Out |
| The reference shape | Gboard ships a 1.4M-parameter CIFG LSTM, 96-dim tied embeddings, 10k word vocabulary, 1.4 MB. Apple's is 34M parameters, 15k tokens |
| Training text | The NUS SMS corpus (Jake asked the authors, they said yes, 2026-09-12) for real texting register; public-domain Enron for volume; the rest written by the local teacher (sequence-level distillation). OpenSubtitles and Reddit forbid commercial ML use and stay out |
| Word lists | SSA baby names (CC0), Wikidata labels (CC0), SCOWL (MIT-like; ship the UKACD notice). wordfreq is share-alike and ranks only. No permissive slang list exists; slang stays hand-curated in `TextingLexicon` |

## Non-goals

- Rule tuning by a model. The Sonnet rule-proposer of the first draft is parked; the
  judge it needed is kept (unit 0). A dictionary gap or a scoring change found by the
  loops is a lead for a hand pass.
- Re-recording the frozen oracle. New stock recordings are new slices, never edits.
- Personal adaptation and typing history across sessions. Waits on a stable number.
- Swipe, other languages, grammar, emoji prediction (unchanged from the parity spec).
- A throughput benchmark of the local model. The dictionary loop is coverage-bound and
  runs as long as it needs to (Jake, 2026-09-12).

## Orientation

| Part | File | Owns |
|---|---|---|
| Scorer | `eval/loop/score.py` | One `swift test` run parsed into numbers: oracle per slice and half, every dev miss, typo benches, protection, completions, suite count |
| Judge | `eval/loop/run.py` (`verdict`, `allowed`) | Keep or revert one change from before and after scores and the changed file list |
| Log | `eval/loop/results.tsv` | One line per attempt |
| Stock recorder | `eval/oracle/record.py` | Types a slice into the real stock keyboard in the simulator, resumable, under the 40-minute cap, about 150 rows per run |
| Word tables | `engine/tools/wordlist.py`, `gen-wordrank.py`, `gen-wordpairs.py`, `engine/tools/vendor/` | The vendored sources and the two memory-mapped binaries |
| Key geometry | `engine/Sources/TypingEngine/KeyboardLayout.swift`, `KeyNeighbors.swift`, `StockLayoutMetrics.swift` | Where every key sits and which keys neighbour which |
| Context seam | `ContextScoring` protocol, `WordPairModel` | What the words already typed say about a candidate. The model replaces the pair table here |
| Guard benches | `engine/Tests/TypingEngineTests/TypoBenchmarkTests.swift`, `KeyboardEvalV4Tests.swift` | Blind corpora the loops never read |

**Non-obvious.**

- A slip cannot say which words exist. It says what the corrector does with a word it
  already has. So the word lists decide membership and the slip corpus proves the
  corrector; Jake's loop lands in both places.
- The oracle has dev and test halves by row number since 2026-09-12; a proposer reads
  dev only, and the judge requires the test half to hold.
- The extension's memory ceiling is about 60 MB; the tables are memory-mapped and the
  footprint is 42 MB steady in the simulator. The model gets what is left.
- Brain, `cheap-inner-search-converges-on-gate-rejected-region`: the objective and
  every gate come from the same run, so a gate-rejected region cannot accumulate.

## Decomposition

**0. The judge (carried from the first draft, one unit left).** `run.verdict` and
`run.allowed` turn the RED tests in `eval/loop/test_loop.py` green. Each loop supplies
its own allowlist: the dictionary loop may change `engine/tools/vendor/`, the
generators and the two binaries; the model loop may change the model file and the
`ContextScoring` implementation; neither may touch a corpus, the oracle, `EVAL.md`,
`app/`, or a bench. Keep rule: the oracle's dev half rises, the test half holds, every
bench holds, no new red test.

**1. Word sources.** SSA names, Wikidata company and brand labels, SCOWL `words` and
`upper` join the vendored sources with their notices. Each new word needs a rank on the
AOSP 0-255 scale: SSA count for names, Wikidata sitelink count for brands, SCOWL size
band for words. Generators reproduce the binaries byte for byte.

**2. Stock membership.** A `words` slice for the recorder: each candidate word typed
into stock in a neutral carrier ("i said <word> today"). Stock leaves it as typed:
accepted. Stock corrects it: dropped, logged with what stock produced. Batches of 150
per run, resumable, unattended for days. Accepted words enter the tables; a batch is
one judged change (unit 0).

**3. The slip corpus.** From the key geometry, every single slip of every word in the
top N: neighbour substitution, dropped letter, doubled letter, transposition, and a
stray or missing space at each boundary. Rows carry (typed, intended, kind, tap
points). The loop is a diff, not a test run (Jake, 2026-09-12): the same batch of slips
is typed into stock by the recorder and into our engine by `swift test`, and the rows
where the two disagree are the work list, grouped by kind. Stock is the slow side, 150
rows per run; ours is 400 rows in five seconds. The full judge runs once per commit,
never per batch. The slip rows also become the typo side of the model's training data.
The generator is deterministic and every recorded batch is frozen.

**4. Teacher text.** A local model on the Studio (qwen2.5 7B via ollama to start) writes
casual English messages from seeded prompts: a topic, a register, three words from the
list. Deduplicated, filtered to the vocabulary, stored under `eval/corpus/teacher/`.
The NUS SMS corpus (about 67k English messages, used with the authors' permission,
recorded in `engine/tools/vendor/NOTICE`) is the real texting register, and public-domain
Enron mail adds volume. No throughput target; the loop runs until the pilot has what it
needs (200k sentences), then keeps going.

**5. The student, piloted.** A 1.5M-parameter model in the Gboard shape (CIFG LSTM or a
two-layer transformer, 96-dim tied embeddings, 10k word vocabulary from `WordRank` plus
unknown) trained on the teacher text with slips from unit 3 mixed in, exported to Core
ML, loaded behind `ContextScoring` in place of `WordPairModel`. The pilot answers one
question: on the oracle's context and nospace dev halves, does the student beat the
pair table? If it does not, the unit stops and the milestone reopens with Jake. If it
does, memory and latency are measured on device and unit 4b of the parity spec ticks.

Units 1 to 3 and 4 run in parallel. Unit 5 waits on 3 and 4.

## GOAL

Jake types a friend's name, a brand, or a word with his thumb off by one key, and
SmartSpace does what Apple's keyboard does. A loop he can leave running for days widens
the dictionary and reports every slip the corrector gets wrong, and every kept change
is one commit he can read. The context model is tried before it is trusted: one number
says whether it beats the table it replaces.

## CHECKS

1. **vision:5** `eval/loop/test_loop.py` is green: the judge keeps a change only when
   the oracle dev half rises, the test half holds, every bench holds, no test turns red,
   and no file outside the loop's allowlist moved.
2. **vision:5** the word tables regenerate byte for byte from the vendored sources
   with SSA, Wikidata and SCOWL included, and each source ships its notice in
   `engine/tools/vendor/NOTICE`.
3. **vision:5** `python3 eval/oracle/record.py <udid> words` records a batch of
   candidates from stock, resumes after a kill, and writes accepted and dropped words to
   `eval/oracle/words-<date>.tsv`; the names slice holds at or above 46/50 and the
   protection corpus at or above 100/96 after every accepted batch.
4. **vision:1,5** `python3 eval/slips/gen-slips.py` writes the slip corpus from the key
   geometry alone; every batch recorded from stock joins the oracle as the `slips`
   slice, and `OracleAgreementTests` prints its agreement per kind beside the other
   four slices, with the disagreeing rows as the work list.
5. **vision:5** `eval/corpus/teacher/` holds at least 200k deduplicated sentences with
   the prompt seed and model recorded per file, generated on the Studio.
6. **vision:5** the pilot number: `ContextModelTests` prints the oracle context and
   nospace dev-half agreement with the student behind `ContextScoring` and with the pair
   table, in one run. The unit closes only if the student's number is higher on both.
7. **vision:1** with the student loaded, the extension stays under 55 MB resident on
   device and a commit decision takes under 10 ms; `swift test` stays green at or above
   431 tests, and `eval/parity/run-parity.sh` reproduces the `EVAL.md` numbers.

## LOOP

Dictionary: `python3 eval/loop/run.py --loop words --udid <udid>` from the repo root,
unattended, until the candidate lists are exhausted. Teacher: `python3
eval/corpus/teach.py --host studio` until stopped. Jake reads `eval/loop/results.tsv`
and `git log --author=autocorrect-loop`.

## Decisions

| Decision | Reason |
|---|---|
| Local models on the Studio, not Haiku | Jake's call 2026-09-12; the Studio is idle and the loop is coverage-bound |
| NUS SMS plus Enron plus teacher text | NUS SMS is the one real texting corpus and its authors gave Jake permission (2026-09-12); Enron is public domain; generated text is ours |
| Word-level 10k vocabulary from our own list | The embedding table is what made every public model too big |
| Stock as the membership filter | The goal is agreement with stock, so a word stock rejects is a disagreement waiting to happen |
| Slips prove the corrector, lists decide membership | A slip cannot say which words exist |
| The model is piloted before it is trusted | A model that does not beat the pair table costs memory for nothing |
| Rule tuning by Sonnet parked | Jake redirected to dictionary and model; the judge survives because both loops need it |
| One commit per kept batch, author `autocorrect-loop` | `git log --author` audits; one revert undoes one |

## Progress

- [x] 0 judge -- verdict and allowed green, 13 tests (2026-09-12)
- [x] 1 word sources -- ssa-names.tsv (104,819 names, 1880-2024) and
      wikidata-brands.tsv (1,841 single-token labels) vendored CC0;
      candidates.py orders 17,726 candidates at floor 200, brands first. SCOWL
      deferred: the AOSP list is wider and the hunspell form needs affix expansion
- [x] 2 stock membership -- live 2026-09-12: batch 1 of 150 brands asked stock,
      88 accepted (SpaceX, Uber, GitHub; dropped a24, arxiv, BlackRock), kept by the
      judge with every number flat, two commits authored autocorrect-loop on
      loop/words. The loop runs on in ../smartspace-words, 9 batches queued
- [x] 2 stock membership -- live 2026-09-12: batch 1 of 150 brands asked stock,
      88 accepted (SpaceX, Uber, GitHub; dropped a24, arxiv, BlackRock), kept by the
      judge with every number flat, two commits authored autocorrect-loop on
      loop/words. The loop runs on in ../smartspace-words, 9 batches queued
- [x] 3 slip corpus -- 158k slips generated, bench in the suite (88% corrected,
      splits 26%), adjacency pinned; the 150-row sample recorded from stock
      2026-09-12: agreement 110/150 (drop 15/30, split 13/30 are the work list). The full 158k bench takes 175s in a release build (1.1ms a row;
      the 46ms was debug overhead). Split slips: 23% corrected, 8,664 miscorrected
- [~] 4 teacher text -- NUS SMS 16,265 messages in; teach.py writes about two
      messages a second from qwen2.5:7b on the Studio; the 200k run started
      2026-09-12
- [~] 5 student pilot -- ContextModel (1.74M parameters, float16, mapped) behind
      ContextScoring; trained on 16,926 sentences the pilot ties the pair table
      (context/dev 35/50, nospace/dev 32/50, 2 of 200 rows differ). Rerun when the
      teacher run reaches 200k sentences; the model only reaches distance ties and
      split decisions, and most context misses are stock leaving a typo alone
