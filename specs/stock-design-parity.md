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

- [x] A: engine StockKeyTheme + KeyLegend (KeyTheme.swift, TDD): role
      fills light/dark x rest/pressed, active shift, blue return, balloon
      fill, 1pt shadow, 26/23/16pt legends. Values: KeyboardKit 9.9.1
      (research 2026-08-10, high confidence).
- [x] B: QuickType bar flat restyle: 17pt candidates, 1x30pt hairlines.
- [x] C: key-preview balloon: CalloutGeometry (engine, TDD) + KeyPopView
      (neck path, 34pt light label, 0.05s dwell).
- [x] D: alternates callout: cap-colored bubble fused to the key, flat
      20pt items, blue pill selection.
- [x] E: press feedback: function caps swap levels via
      configurationUpdateHandler; letters keep the balloon only (stock).
- [x] F: return-key action tint incl. pressed states.

All controller edits are compile-unverified until Xcode (2026-08-11).

## Known simplifications (each is a Jake-visible delta candidate)

- Edge balloons clamp to the screen instead of skewing the bubble the
  way stock does on q/p.
- The alternates callout has no neck curve over the origin key; the
  preview balloon has the full neck.
- Stock dims the whole key area to 0.5 and blanks legends during the
  space-bar cursor drag; ours keeps the keys as-is.
- Return-while-empty: stock greys the blue return until the field has
  text (enablesReturnKeyAutomatically); not modeled.
- iOS 26 Liquid Glass deltas not applied: radius 9, no shadow, row
  height 56, glassier dark fills. Needs an availability fork on the
  Xcode machine; iPhone 17 shows iOS 26 chrome.
- QuickType bar height: ours 44pt (own AX measurement "~44"), one web
  source says 45. Device-measure item.
