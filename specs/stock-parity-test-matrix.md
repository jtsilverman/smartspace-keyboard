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
| Backspace hold: char phase then whole-word phase | chars repeat, sustained hold deletes word chunks | PINNED BackspaceRepeaterTests (controller wiring compile-unverified: no Xcode on this machine) |
| Backspace hold exact timings | phase onset, word cadence | DEVICE-MEASURE: research confirms no published constants exist anywhere; measure on iPhone 16/17 hardware |
| Trailing-space absorption | sentence mark eats the auto-inserted space ("hello " + "," -> "hello,") | PINNED TrailingAutoSpaceTests; exact stock character set device-verifiable |
| Return key label per host field type | search/go/return | PINNED KeyboardLayoutTests |
| Shift/123 slide-to-character (one-gesture capital or symbol) | release on origin = tap; on character = modified commit; on nothing = cancel | ENGINE PINNED FunctionKeySlideTests; surface wiring PENDING-XCODE (function keys are plain UIButtons today, the gesture dies on release) |
| Host autocapitalization trait (.none/.words/.sentences/.allCharacters) | email/URL fields never auto-shift | PINNED AutocapTraitTests; proxy wiring compile-unverified |
| Host autocorrection opt-out (.no) | password/code fields never correct | wired in applyAutocorrectOnCommit; sim-verify pending |

## 2. Autocorrect and autofinishing

| Behavior | Stock semantics | Status |
|---|---|---|
| Commit on space, top suggestion, 3-slot bar | original leads, two alternatives | PINNED AutocorrectControllerTests |
| Undo, protection, lexicon, session protect | revert protects case-insensitively | PINNED CorrectionSessionTests |
| Case preservation (teh/Teh/TEH), acronym guard | leading cap survives, all-caps never corrected | PINNED CorrectionDecisionTests |
| Contractions (im, dont), homograph guard (well, ill, its) | ambiguous real words never transformed | PINNED ContractionRuleTests |
| Digits, URLs, handles, hashtags never corrected | | PINNED WordBoundaryTests |
| Guess re-rank: edit distance then frequency | | PINNED CorrectionRerankTests |
| Commit delimiters beyond space (period, comma, return) | . , ! ? : ; commit; apostrophe/hyphen never | PINNED CommitDelimiterTests |
| Literal typed word in quotes when a commit would correct it | clean/protected/lexicon words unquoted | PINNED QuotedLiteralSlotTests (CompletionBarTests:19 sim-verify pending) |
| Backspace immediately after a commit | stock primary UX is underline + tap-to-revert (iOS 17+); stock's own re-correction protection is reported broken | VARIANT: our bar undo + session protect is the deterministic equivalent; underline UI is a Jake call |
| QuickType bar never empty (three predictions at rest) | spec lists as open tell | GAP (spec non-goal boundary; Jake call) |
| Completions: typed + two, verbatim accept | | PINNED completion tests |

## 3. Layout and design

| Behavior | Stock semantics | Status |
|---|---|---|
| 402pt (iPhone 17 class) full geometry | AX-measured 2026-07-31 table | PINNED StockLayoutMetricsTests |
| Visible caps, white fill, 5pt radius, shadow | pixel-scan verified | PINNED (sim, 2026-07-31) |
| 393pt (iPhone 16 class) geometry | research 2026-08-10: 393 and 402 share one device bucket (54pt rows, 216pt area); widths scale linearly, which is what StockLayoutMetrics does | BLOCKED for the confirming AX dump (needs Xcode); model already correct, medium confidence |
| Key cap colors, typography, callouts, press feedback | KeyboardKit 9.9.1 values, high confidence | PINNED KeyThemeTests + CalloutGeometryTests (engine); controller wiring compile-unverified; see specs/stock-design-parity.md |
| Key preview bubbles, alternates popup | down/up lifecycle | PINNED (sim suites) |
| iOS 26 Liquid Glass metric deltas vs iOS 18 | research: visual chrome only; no documented behavior deltas | RESOLVED: no behavior rows to add. iOS 26.0-26.3 ships a keystroke-drop bug (Apple-acknowledged, patched 26.4); parity targets 26.4 semantics, never emulate the bug |

## Decisions for Jake

- `'70s` elision: stock inserts an opening curly quote before digits (its
  documented smart-quote failure). Ours flips to an apostrophe
  (digitFlipsOpenSingleQuoteToApostrophe), the typographically correct
  form. Exact parity means copying stock's bug. Current pick: keep ours.
  Flag if wrong.
- Contraction bias: stock corrects "well" -> "we'll" aggressively and
  inconsistently (multiyear complaint threads). Our homograph guard never
  transforms ambiguous real words. Research verdict: stock is
  non-deterministic here; deterministic guards are the defensible pin.
- Backspace-after-commit: see VARIANT row above.

## Device-measure checklist (Jake, iPhone 16/iOS 18 + iPhone 17/iOS 26.4+)

Research confirms none of these constants are published anywhere; ours are
guesses until measured. Screen-record at 60fps, count frames.

1. Double-tap shift caps-lock window (ours: 0.35s, ShiftState.doubleTapWindow).
2. Double-space period window (ours: StockDoubleSpace window constant).
3. Backspace hold: char-repeat interval, word-phase onset (ours: 0.1s,
   20 ticks), word-phase cadence (ours: 0.45s).
4. Trailing-space absorption character set: type a prediction accept, then
   each of . , ! ? : ; ' " ) -- record which eat the space (ours: . , ! ? : ;).
5. Absorption after a plain typed space (ours: never absorbs) and whether
   stock re-appends the space after the mark (ours: does not).
6. '70s: confirm stock still curls the wrong way on iOS 26 before deciding
   the decision row.
7. 393pt stock AX dump (StockMetricsDumpTests on an iPhone 16-class sim,
   needs Xcode) -- checks whether stock scales linearly from 402pt.

## Xcode-machine checklist

1. Build the keyboard target; the controller edits from 2026-08-09 and
   2026-08-10 are compile-unverified (BackspaceRepeater, TrailingAutoSpace,
   commit delimiters, quoted slot, host traits, role colors, KeyPopView,
   callout restyle, bar restyle).
2. Run the sim suites; CompletionBarTests:19 asserts the quoted label;
   the backspace key is now the delete.left symbol with accessibility
   label "⌫" (UI suites address it by that label).
3. Wire FunctionKeySlide into KeyTouchSurface (claim __shift/__more
   zones, arm-on-down, slide commit, restore) and re-run KeyboardHold,
   FastTyping, SmokeTests.
4. Run StockMetricsDumpTests at 393pt (device-measure item 7).
5. Screenshot-diff light and dark mode against stock: role colors,
   balloon shape, callout, bar hairlines (specs/stock-design-parity.md).
6. Liquid Glass fork for iOS 26 (radius 9, no shadow, 56pt rows,
   glassy fills) once the base design verifies on iOS 18.

## Loop log

- 2026-08-09 iteration 1: baseline 315 engine tests green. Matrix created.
  Deep-research fired (stock semantics, 7 axes). BackspaceRepeater RED
  (0aa0ac0) then GREEN (9e02a51); suite 323 green. Controller now paces
  0.1s chars / 0.45s word chunks; cadence constants await research.
  Next: research lands -> trailing-space absorption, commit delimiters,
  backspace-after-commit; 393pt geometry stays BLOCKED without Xcode.
- 2026-08-09 iteration 2: research landed (5 axes, adversarially verified;
  synthesis at tasks/wrxortam3.output). Three units RED/GREEN: commit
  delimiters (bad121d/f95eaea), trailing auto-space absorption
  (2cc8004/9fded75), quoted-literal slot (11b94b5/b430ff6). Suite 337
  green. Renderer had quoted every typed slot; now only correctable ones.
  Next: shift+slide-to-letter verify, sim suites on an Xcode machine,
  device-measure list for Jake.
- 2026-08-09 iteration 3: two units. FunctionKeySlide engine machine
  (b55c7b3/0636f89) -- surface wiring needs Xcode. Host traits: auto-shift
  follows .none/.words/.sentences/.allCharacters, autocorrect honors the
  host opt-out (baace8f/66f4dd6). Suite 351 green. Loop stopped: every
  open row is blocked on Xcode, hardware measurement, or a Jake decision
  (see checklists above). Restart with /loop on an Xcode machine.
