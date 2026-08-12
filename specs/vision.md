---
status: active
---
# Vision: SmartSpace keyboard

The epic layer. Injected into every session in this repo; loops re-read it every iteration.
Details live in the linked docs; this file stays under 80 lines.

## The picture (Jake's words, 2026-08-12)

"The keys look the same, emoji selection pane looks the same, the 3 word suggestions and
autocorrect looks the same, the autocorrect feels the same where it autocorrects when I type
incorrectly. I've been typing with the Apple keyboard for years and my fingers already move
automatically to the keys, so I want the same exact keys covering the same exact areas so I don't
have to relearn where to press. There's no dead space on the Apple stock keyboard, it gives the
letter preview when pressed, I can drag to type. My muscle memory is ingrained: if something
changes and I suddenly have to press somewhere else for a certain key, that would be very annoying."

## The one change

Double-tapping the spacebar chooses the correct punctuation for the sentence and the typer's own
style, instead of defaulting to a period every time. Everything else is exactly stock. The hero
mechanics (candidate cycling on further space taps, triple-space ellipsis, configurable candidate
set) are specified in `PRODUCT.md`.

## The invariant that outranks everything

Jake's muscle memory is the acceptance test. Key positions, hit areas, previews, drag-to-type,
sounds, and the emoji pane must be indistinguishable from stock. A loop that improves the
punctuation engine while moving a key has failed, whatever its tests say. The visible layer Jake
judges by eye and thumb is the target; engine simulations are proxies (trace
2026-08-11-simulated-parity-while-visible-layer-unjudged).

## Milestones, as Jake judges them

1. Parity locked: Jake types on it daily and never notices a difference from stock.
2. Double-tap's first pick is accurate at a threshold (number set at that milestone's contract).
3. When punctuation is ambiguous, the correct mark is within the top two picks (the second pick is
   one extra space-tap away, per the cycling mechanic).
4. The punctuation engine improves with continued use, matching Jake's personal style.

Build phasing and unit status live in `WORKPLAN.md`. Behavior journeys live in `UX.md`.

## Design references

- The reference is the stock iOS keyboard itself, on-device, side by side.
- The reverse-engineered visual constants live in the engine as tested data (see
  `specs/stock-design-parity.md` and `specs/stock-parity-test-matrix.md`).
- Approved renders and locked copy land here as they are approved. None yet.

## Decision log (newest first, cap 10)

- 2026-08-12: Milestone 2 threshold deferred to its contract; the vision stays number-free.
- 2026-08-12: Muscle-memory invariant declared the top acceptance test, above engine metrics.
- 2026-08-12: Scope held to the one change; languages, themes, iPad stay out until the picture ships.

## Handoff (update when state moves)

As of 2026-08-12: the punctuation engine (pure Swift package) has question/exclamation detection
built and tested; the parity loop is stopped; the emoji panel is parked pending the Xcode day
(commit a2860e9). The next session picks up from `WORKPLAN.md` phase status.
