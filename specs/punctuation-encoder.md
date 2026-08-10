---
status: draft
---

# Punctuation ranking encoder experiment

## Intent

Maximize first-guess (then second-guess) correctness of the double-space punctuation ranking, replacing/augmenting the rule-based `PunctuationEngine` with a small on-device encoder classifier (punctuation-restoration style: sentence in, probability over marks out). Phase 0 builds the measurement rig before any model: a frozen benchmark of casual-register sentences with known terminal punctuation, scored top-1 / top-2, with the current rule engine as the baseline row. Then candidate models (distilled BERT-family encoder, quantized to Core ML) are trained/evaluated against it, and a model only ships if it beats rules on top-1 without regressing top-2 as a set.

## Acceptance criteria

1. Frozen benchmark exists: >=1000 casual-register sentences (dialog/message style, not news prose), each labeled with its real terminal mark from the source corpus; stripped-input -> label format; committed with provenance notes.
2. Harness reports top-1 and top-2 accuracy per mark class (. ? ! , ...) and overall, runnable as one command; current `PunctuationEngine` scored as the baseline row.
3. At least one trained encoder candidate evaluated on the same benchmark, with a results table rules-vs-model.
4. Ship gate defined by data: model adopted only if top-1 improves and top-2 does not regress.
5. Any shipped model fits the keyboard-extension constraints: <=30MB in-bundle, <50ms inference on-device (measured, not estimated).

## Non-goals

- No change to the live keyboard's double-space seam in this experiment (wiring a winning model is its own follow-up spec).
- No LLM/generation route (memory cap ~60-70MB in extensions kills it).
- No personalization interplay yet (PersonalRanking reranking stays as-is on top of whatever base ranking wins).

## Open questions for Jake sign-off

- Corpus pick: OpenSubtitles (dialog register, huge, free) vs Reddit/message-style dumps. Recommend OpenSubtitles for v1.
- Mark classes: start with {. ? ! ,} or full current candidate set?
