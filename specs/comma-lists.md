---
status: active
---

# List recognition + comma-second ranking

## Intent

Double-space works for lists (Jake 2026-07-31): comma is always one cycle tap from period and vice versa, and genuinely list-shaped contexts guess comma first. Stacked on feat/host-app-settings (needs comma/quote in the default candidate set).

## Acceptance criteria

1. Every period-first candidate order ranks `,` second; the comma-first order already ranks `.` second. Question/exclamation/quote-first orders unchanged.
2. New list rule (in-list signal): the sentence already contains a comma boundary AND the chunk after the last comma is short -> predict `, . ? ! "` under a new `PredictionRule` case. Fires from item 2 of a list onward; item 1 stays the hedge (period first, comma one cycle tap via AC 1). Close detection (Jake 2026-07-31): a post-comma chunk opening with "and"/"or" is the final item ("chips, watermelon, ice, and sprite") -> period-first again.
3. Comprehensive list eval: blind-authored rows (authors never see engine source; grounded in real texting patterns) covering list boundaries item-1 and item-2+, plus statement/question look-alikes that must NOT fire the rule; dev/test split with frozen accuracy thresholds in a NEW corpus file (BlindCorpus stays frozen and untouched).
4. Frozen blind-corpus regression: top-1 accuracy unchanged; the AC-1 rank change's top-2 delta measured and reported before merge.
5. PersonalRanking untouched; it keeps layering on top of the new rule's order.

## Non-goals

- Prospective item-1 list detection via intro-verb stems ("we need", "grab") -- measured by the AC 3 rows first; a v2 rule only if the numbers justify it.
- Per-context personalization (PersonalRanking stays per-rule).
- `: ; -` prediction rules; those marks stay engine-absent (dead-toggle cleanup is a separate decision).
- e2e ScenarioCorpus edits (e2e-040/041 already cover list boundaries live with punct-top2 tolerance).

## Progress

- [x] Spec signed (Jake, in-chat 2026-07-31: "yep" + /goal)
