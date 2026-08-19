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

- ~~Edge balloons clamp~~ Fixed: overhang redistribution skews the
  bubble like stock (CalloutGeometry.overhangs).
- ~~Alternates callout neckless~~ Fixed: CalloutPath serves both
  callouts; the bubble grows toward the screen center, items flip.
- ~~Space-drag keys unchanged~~ Fixed: legends blank during cursor mode.
- ~~Return-while-empty not modeled~~ Fixed: grey + inert until text.
- ~~Liquid Glass not applied~~ Fixed for chrome: radius 9, no shadow,
  glassy fills fork on iOS 26 (StockKeyTheme liquidGlass). Row height
  56 vs our measured 54 stays a device-measure question; geometry
  unchanged until measured.
- QuickType bar height: ours 44pt (own AX measurement "~44"), one web
  source says 45. Device-measure item.

- Gutters between the caps take no tap in the simulator. A synthesized tap
  6pt wide between every pair of caps never reaches the keyboard's view at
  all, while the same tap on stock always lands (measured 2026-08-18,
  EdgeSweepTests). Giving any view under the point a visible background
  makes every gutter live, so the cause is that KeyTouchSurface is fully
  transparent. Painting the backdrop ourselves would cover the system
  keyboard material, which is the Liquid Glass surface above. Open: does a
  real finger on the device hit the gutter? Jake's device check decides
  whether this is a product bug or a simulator-only artifact.
- Stock's hit map sits a uniform 3.8pt left of the cell edges its own key
  elements report; ours sits on its cell edges. Closing that costs a
  3pt leftward shift of every letter zone (StockBoundaryTests).
