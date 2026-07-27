---
status: active
---

# Stats counters wired to live key events (WORKPLAN 3.7)

## Intent

Every double-space interaction now records its outcome: which rule fired, what the engine guessed, how many cycle taps, and which mark the user finally kept — counts and marks only, never text. Records persist in the extension sandbox (capped log), feed the future stats screen (4.3 reads them), and rebuild PersonalRanking at keyboard load so the candidate order adapts to the user's own habits. Decision: PersonalRanking's live wiring (2.4 logic, no WORKPLAN unit of its own) rides here — same event stream, same seam; flagged in the PR for Jake's veto.

## Acceptance criteria

1. Engine `OutcomeTracker` (swift-test): `smartInsert(rule:guess:wordCount:)` then `finish()` yields a record with kept == guess, cycleTaps == 0, correct bucket; `cycled(to:)` bumps taps and updates kept; `finish()` clears (second call nil); `finish()` with nothing active is nil; a new `smartInsert` overwrites an unfinished interaction; `abandon()` drops the active interaction so a following `finish()` is nil (used when the document and the cycle state diverge — the ground truth is corrupted, so no record).
2. Engine `OutcomeRecord` line codec: `encodedLine` round-trips through `init?(line:)` (hand literals + a generated round-trip loop); malformed lines (wrong field count, bad rule, non-numeric taps) decode nil.
3. Engine `OutcomeLog`: appends persist through the injected store seam and reload; the log caps at 2000 (oldest dropped); `stats` equals `OutcomeStats` of the same records; malformed persisted lines are skipped on load, not crashed on.
4. Live (simulator): after a double-space insert, one cycle tap, and a letter (ends the cycle) in the practice field, the extension's persisted outcome log gains one record with cycleTaps == 1 (read back from the extension container via `simctl get_app_container`; fallback observation: the extension's os_log outcome line, marks only).
5. The SmartSpaceBar candidates closure now serves `personal.reranked(prediction)` and records finished outcomes into both the log and PersonalRanking (code-path check; reranking behavior itself is pinned by the existing 2.4 engine tests).
6. Full simulator suite green; smoke double-space assertions unchanged.

## Non-goals

- Stats screen UI (4.3) — this unit only produces the numbers it will read.
- Opt-in capture/export wiring (2.5's storage/toggle, Phase 4).
- App-group sharing of counts (extension-local until 4.2/4.3 need transport).
- Any record field carrying sentence text (LengthBucket only, by construction).

## Orientation findings (compact)

- Engine types ready: `OutcomeRecord`/`OutcomeStats`/`LengthBucket` (PunctuationEngine/Outcome.swift), `PredictionRule` string-backed, `PersonalRanking.record`/`reranked` (minimum 5 outcomes per rule), `PunctuationEngine.prediction(before:) -> Prediction` (rule + candidates) at PunctuationEngine.swift:275.
- VC hook points: the candidates closure in `spaceTapped` (currently `punctuation.candidates(before:)`) switches to `prediction(before:)` + stash rule + `personal.reranked`; `.insertMark` begins the tracker, `.replaceMark` is a cycle tap; every `spaceBar.nonSpaceKey()` call site is where a cycle ends — finalize there via one shared helper so no site is missed: characterTapped, alternateTapped, backspaceTapped, spaceDragged .began, suggestionTapped, returnTapped, emojiKeyTapped, emojiItemTapped, AND the `.replaceMark` suffix-guard failure branch inside spaceTapped (9 sites), plus `viewWillDisappear` (send/dismiss mid-cycle). The guard-failure site is special: SmartSpaceBar already advanced its cycle but the document got a plain space, so the tracker calls `abandon()` there, never `finish()` — a record with a mark the text never kept would corrupt PersonalRanking's ground truth.
- Persistence seam precedent: `EmojiRecentsStore` + `DefaultsRecentsStore`. Same shape: `OutcomeLogStore` protocol in engine, UserDefaults impl in the extension (`outcome-log` key, `[String]` lines).
- `OutcomeLog`/`OutcomeTracker` live in PunctuationEngine (next to Outcome.swift; TypingEngine unnecessary — no typing-machine coupling).
- Word count for the bucket: whitespace-split count of the context the prediction saw; the count never persists, only the bucket.
- Extension containers on simulator: `xcrun simctl get_app_container <udid> com.jtsilverman.smartspace.keyboard data` (verify at build time; if extension containers are not addressable this way, AC4 falls back to the os_log observation).

## Design (creativity beat)

Alternatives: (a) counters incremented inline in the VC switch arms (braids lifecycle state into UIKit, untestable, misses end-of-cycle edge); (b) chosen — pure `OutcomeTracker` lifecycle + `OutcomeLog` persistence, VC calls three verbs (begin/tap/finish); (c) 10x: full event-sourced analytics with export — non-goal (2.5/Phase 4). Simplest viable: two small pure types, one shared end-of-interaction helper in the VC.

## Decomposition

1. RED: `OutcomeTrackerTests` + codec tests + `OutcomeLogTests` — committed failing.
2. GREEN: `OutcomeTracker`, codec extension, `OutcomeLog` in PunctuationEngine.
3. Wire: `DefaultsOutcomeStore`, VC helper + call sites, reranked closure, os_log line. Live-verify AC4. Suite green.
4. Review, fix, PR (base `feat/emoji-panel`).
