---
status: active
---

# Stock-parity test matrix

Tracker for the parity loop (Jake 2026-08-09: tests must be narrow, edge-case
inclusive, all-encompassing; targets iPhone 16 at 393pt and iPhone 17 at 402pt).
Each row is a stock behavior. The loop burns rows top to bottom by status.

Status codes: PINNED (test exists, green), GAP (stock behavior missing or wrong,
needs RED/GREEN), RESEARCH (exact stock semantics unconfirmed; deep-research
run wf_1ac9e72d-a76 in flight 2026-08-09), BLOCKED (needs a tool this machine
lacks).

## 1. Typing mechanics and spacing

| Behavior | Stock semantics | Status |
|---|---|---|
| QWERTY planes, layer flow | 123/#+= flow, space returns to letters | PINNED KeyboardLayersTests |
| Shift one-shot / double-tap caps lock / auto-shift | window edges, no caps-lock downgrade | PINNED KeyboardLayoutTests |
| Rolled multitouch, gutter zones, slide-select alternates | no dropped taps, per-finger tracking | PINNED KeyTouchTracker/KeyZoneMap |
| Probability-biased hit targets | targets grow toward likely next letters | PINNED BiasedKeyResolverTests |
| Double-space period + window + no chaining | 0.5s-class window, word char before | PINNED StockDoubleSpaceTests |
| Spacebar cursor drag | threshold steps, no double counting | PINNED SpacebarCursorDragTests |
| Smart quotes, em dash, ellipsis, contraction apostrophes | open/close logic, digit guards | PINNED SmartSymbols/ContractionRule |
| Auto-capitalization | enders, newline, quotes, abbreviations, emoji | PINNED CapitalizationTests |
| Backspace hold: char phase then whole-word phase | chars repeat, sustained hold deletes word chunks | GAP -> this iteration (BackspaceRepeater) |
| Backspace hold exact timings | phase onset, word cadence | RESEARCH (constants tunable) |
| Trailing-space absorption | punctuation after accepted prediction pulls before the space | RESEARCH |
| Return key label per host field type | search/go/return | PINNED KeyboardLayoutTests |

## 2. Autocorrect and autofinishing

| Behavior | Stock semantics | Status |
|---|---|---|
| Commit on space, top suggestion, 3-slot bar | original leads, two alternatives | PINNED AutocorrectControllerTests |
| Undo, protection, lexicon, session protect | revert protects case-insensitively | PINNED CorrectionSessionTests |
| Case preservation (teh/Teh/TEH), acronym guard | leading cap survives, all-caps never corrected | PINNED CorrectionDecisionTests |
| Contractions (im, dont), homograph guard (well, ill, its) | ambiguous real words never transformed | PINNED ContractionRuleTests |
| Digits, URLs, handles, hashtags never corrected | | PINNED WordBoundaryTests |
| Guess re-rank: edit distance then frequency | | PINNED CorrectionRerankTests |
| Commit delimiters beyond space (period, comma, return) | which delimiters commit | RESEARCH |
| Backspace immediately after a commit | stock revert affordance semantics | RESEARCH |
| QuickType bar never empty (three predictions at rest) | spec lists as open tell | GAP (spec non-goal boundary; Jake call) |
| Completions: typed + two, verbatim accept | | PINNED completion tests |

## 3. Layout and design

| Behavior | Stock semantics | Status |
|---|---|---|
| 402pt (iPhone 17 class) full geometry | AX-measured 2026-07-31 table | PINNED StockLayoutMetricsTests |
| Visible caps, white fill, 5pt radius, shadow | pixel-scan verified | PINNED (sim, 2026-07-31) |
| 393pt (iPhone 16 class) geometry | assumed proportional, never measured | BLOCKED: no Xcode on this machine; needs AX dump on a 393pt sim |
| Key preview bubbles, alternates popup | down/up lifecycle | PINNED (sim suites) |
| iOS 26 Liquid Glass metric deltas vs iOS 18 | | RESEARCH |

## Loop log

- 2026-08-09 iteration 1: baseline 315 engine tests green. Matrix created.
  Deep-research fired (stock semantics, 7 axes). Started BackspaceRepeater
  RED/GREEN. Found: held backspace bypasses word deletion (2 chars/tick),
  KeyboardViewController.swift:604-609.
