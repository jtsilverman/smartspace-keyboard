---
status: active
---

# Rules v2: invariant-first lift of the six weak blind classes

## Intent

Lift the blind benchmark's weak scenario classes with GENERAL rules: each rule captures a linguistic structure, never a corpus row. Gate metric is top-2 (ship bar: >= 80% blind test / >= 85% real-v3 test). Approved by Jake 2026-07-27.

## The invariants (from clustering 232 blind-dev misses)

1. Quote-introducer: clause ending in a communication/inscription verb ("the sign says", "she texted", "bro goes", "his exact words were", BE + "like") or standalone NP headed by a quotation noun ("text from dad this morning", "her yearbook quote") -> " first. Verb/noun classes are bounded linguistic sets.
2. Exclamation, four structural sub-invariants: exclamative syntax ("what a X", "such a X"); superlative + time-window ("best news all week", "loudest crowd ever"); completion markers ("finally", "at last", "just + past achievement"); second-person praise ("you crushed/killed/nailed it"). Open-vocabulary emotion is the ML lane; remainder handled by ranking ! second on first-person completion statements (top-2 credit).
3. Comma-vocative/lead-in: verbless opener <= 4 words that is greeting + addressee ("hey mom") or meta-discourse noun ("quick thing", "side note", "in other news") -> , first.
4. Comma-conjunction: fronted contrastive/summative adverbial idioms ("then again", "even so", "that said", "at the end of the day", "on the flip side", "all things considered", "to be fair") -> , first.
5. Urgent-imperative: verb-first imperative + urgency marker (now/rn/asap/quick/immediately) or hazard interjection (watch out, duck, heads up) -> ! first; calm imperatives keep "." (already 100%).
6. Greeting split: "happy/merry/welcome + occasion" -> !; flat greetings (gm, morning, hey) stay ".".

## Acceptance criteria

1. Each rule lands RED->GREEN; RED tests use NOVEL sentences of the scenario type, asserted (mechanically) to not duplicate any corpus row.
2. Blind-dev per-form top-2 >= 70% for each of the six classes.
3. Rule-regression gates hold (top-1 >= 90%, top-2 >= 97% on Corpus.swift).
4. Real-v3 dev top-2 does not drop below 91%.
5. Test halves untouched during development; one final aggregate read at the end.
6. No corpus file edited in any commit that touches engine source (freeze).

## Non-goals

- Rising-statement / elliptical question re-ranking (top-2 already ~100%).
- ML. Corpus edits. New marks.

## Decomposition

One commit-sized unit per invariant (1-6), each: RED novel-sentence tests -> minimal general rule -> full suite + blind-dev re-run -> commit. Final unit: aggregate test-half read + EVAL.md baseline update (data-only commit).
