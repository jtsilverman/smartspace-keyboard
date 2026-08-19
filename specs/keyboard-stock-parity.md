---
status: active
---

# Keyboard stock parity

## Intent

The keyboard types, looks, and feels indistinguishable from the stock Apple iPhone keyboard down to spacing, response, and key preview bubbles; the only perceivable difference is the SmartSpace behavior (Jake 2026-07-31, from real-device use: "no one will switch if it feels clunky or they have to relearn how to type"). Device feedback driving this: hits don't register during fast typing, some keys lack the preview bubble, an AG:BLOCKED debug badge is visible, spacing/sizes are off stock.

## Acceptance criteria

1. Metrics: portrait key sizes, gaps, row insets, row heights, and corner radii match stock iPhone within 1pt on the dev device class; letters/layers/bottom row all conform. Verified against stock-keyboard screenshots at identical scale.
2. Touch: burst typing with rolled touches (next key down before last key up, both thumbs) drops zero characters. Custom touch handling on the keyboard surface (not per-UIButton tap recognition); each key's hit zone extends into the surrounding gutters like stock. XCUITest cannot simulate rolled multitouch, so this is engine-of-touch unit-tested (hit-test mapping) + device-verified by Jake.
3. Key preview bubbles: every character key shows the stock-style magnified bubble at touch-DOWN, dismissing on touch-up; function keys (shift, backspace, layer, space, return) show none, matching stock. Alternates long-press popup still works.
4. No debug chrome: the AG probe badge is gone from the keyboard surface (probe verdict stays observable in the system log only).
5. Responsiveness: no synchronous per-keystroke work on the touch path beyond text insertion; autocorrect context reads and suggestion-bar refresh are deferred off the tap's critical path. Fast-typing latency on device is Jake-verified.
6. Existing behavior unbroken: full engine suite green; sim suites (smoke, smart typing, settings toggles, autocorrect bar, completion bar, emoji, cursor drag) green with only mechanical test updates (identifiers stay stable).

## Non-goals

- ~~Word-prediction/QuickType parity beyond the existing completion bar~~
  Lifted 2026-08-10: Jake's goal is full indistinguishability; the at-rest
  prediction bar is built (NextWordPredictor, stock-parity-test-matrix).
- The Full Access / in-keyboard-settings fork (open decision, separate spec).
- Landscape and iPad layouts (portrait iPhone first; others follow the same metrics table later).
- ~~Sound effects~~ Lifted 2026-08-10: playInputClick + a conforming
  input view need no Full Access; wired, honors the system Keyboard
  Clicks setting. Stock's distinct modifier/delete click variants are
  not reachable from an extension (system service limitation).

## Measured visible key caps (pixel scan of stock, 402pt @3x, 2026-07-31)

Accessibility frames are TOUCH CELLS, not the key you see; the visible cap
was measured by scanning screenshot pixels. Stock: cap 32.83 x 43.0pt,
horizontal gap 6.67, vertical gap 11.0, row pitch 54, first cap x 7.0,
row-2 indent half a cell, corner radius ~5pt, caps WHITE on the grey
backdrop. Cap sits 1pt below its cell top, so the cell hangs 10pt lower
than the key. Cap row tops: 591.33 / 645 / 699 / 753.

Ours after this spec (same scan): rows 591 / 645 / 699 / 753, cap 33.0 x
43.0, gaps 6.5 / 11.0, pitch 54 -- every row within 0.33pt of stock.

## Measured stock geometry (iPhone 17 Pro class, 402pt wide, AX dump 2026-07-31)

Hit cells abut edge-to-edge (no dead gutters -- AX frames are touch zones, the
visible key is the cell minus visual insets). Row pitch exactly 54pt, rows at
y 590/644/698/752 (4 x 54 = 216). Letter cell pitch 39.33 = (402 - 2x4.67)/10;
row 2 indents half a cell (A at x 24.33). shift/delete cells 51.3w. Bottom row:
123 cell 49.33 at x 4.67, emoji 49.33 at x 54, space 197.33 at x 103.33,
return 99 at x 300.67. Suggestions bar sits above row 1 (~44pt).

## Progress

- [x] Unit A: StockLayoutMetrics from the AX-measured stock table (TDD, measured-frame oracle); keyboard renders frame-based from the cells; cells double as touch zones
- [x] Unit B: KeyTouchSurface -- rolled multitouch per-finger tracking, gutter/edge hit zones, hold-for-alternates; buttons passive under PassthroughView rows (an over-layer culled them from AX; stacks swallowed fall-through touches; eager zone capture read stale frames -- all three found by sim suites)
- [x] Unit C: key-pop bubbles driven by the surface at touch-down/move (pre-existing pops, now on every character touch path)
- [x] Unit D: AG badge gone; probe verdict logs only
- [x] Unit E: completion refresh coalesced off the tap's touch-event cycle
- [x] Sim verification: engine 298 green; smoke/smart/settings/emoji/cursor-drag/autocorrect-bar/completion-bar suites green on the final build
- [x] Unit F (Jake, device: "keys are still smaller"): visible caps were never measured, only touch cells -- the guessed 3/6pt inset plus a `.gray()` configuration (grey-on-grey) and the configuration's default `.dynamic` corner style (pill-shaped caps) made keys read small. Now: measured cap inset, white caps, fixed 5pt radius, stock 1pt bottom shadow, stock glyphs for emoji/return, blank space bar, 44pt bar + flush 216pt key area (+7pt measured overhang). Verified pixel-for-pixel against a stock screenshot.
- [ ] Jake device feel-verification (AC 2/5 device halves; AC 1 now pixel-verified in the simulator)
- [ ] Empty suggestion bar: stock always shows three predictions, ours is blank until typing (QuickType parity is a spec non-goal; the empty grey band is the visible tell)
- [ ] Sim-state gotcha recorded: mistrained PersonalRanking lives in the group-container plist (Containers/Shared/AppGroup/<id>/Library/Preferences/group.com.jtsilverman.smartspace.plist), invisible to `simctl spawn defaults read group...`
