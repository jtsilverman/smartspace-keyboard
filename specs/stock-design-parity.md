---
status: active
---

# Stock design parity

## GOAL

The keyboard is visually indistinguishable from stock iOS at a glance: key
colors per role, typography, the QuickType bar, the key-preview balloon, the
alternates callout, and press feedback. Geometry parity (cells, caps, pitch)
already holds via StockLayoutMetrics; this spec covers everything the eye
sees on top of it. Xcode arrives 2026-08-11; controller edits compile then.

## CONTRACT

1. Function keys (shift, delete, 123, emoji, globe, return) render grey in
   light mode while letters and space render white; dark-mode fills match
   stock per role; a pressed function key swaps to the letter fill.
2. QuickType bar slots are flat text with hairline separators between
   slots. No key-cap chrome on the bar.
3. The key-preview balloon is cap-colored, contiguous with the key below,
   shadowed, and has no border.
4. The alternates callout uses the same balloon language; the selected
   option is a system-blue rounded highlight.
5. The return key tints blue for action return types (search, go, send).
6. Every color, font size, radius, and path constant lives in the engine as
   tested data with a source citation; the controller maps data to UIKit
   and holds no visual constant of its own.

## LOOP

Research (three web agents, 2026-08-10) -> engine theme tables (TDD) ->
controller mapping -> Xcode compile + sim suites (2026-08-11) -> Jake
device check.

## Units

- [ ] A: engine StockKeyTheme: KeyRole, RGBA fills (light/dark x
      rest/pressed), legend fonts per role, shadow spec. Exact values from
      the research reports.
- [ ] B: QuickType bar flat restyle (controller).
- [ ] C: key-preview balloon: engine path data + controller shape layer.
- [ ] D: alternates callout restyled to the balloon language.
- [ ] E: press feedback: function-key fill swap.
- [ ] F: return-key action tint.
