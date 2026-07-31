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

- Word-prediction/QuickType parity beyond the existing completion bar (separate spec if the current bar's suggestions are the gap).
- The Full Access / in-keyboard-settings fork (open decision, separate spec).
- Landscape and iPad layouts (portrait iPhone first; others follow the same metrics table later).
- Sound effects (keyboard clicks are a system service tied to Full Access; revisit with the fork).

## Progress

- [ ] Unit A: stock metrics table + layout conformance (sizes, gaps, insets, radii)
- [ ] Unit B: custom touch surface -- rolled/multitouch, gutter hit zones, touch-down feedback
- [ ] Unit C: key preview bubbles on all character keys
- [ ] Unit D: AG badge removed; probe verdict to log only
- [ ] Unit E: per-keystroke work off the touch critical path
- [ ] Device install + Jake feel-verification loop after each unit lands
