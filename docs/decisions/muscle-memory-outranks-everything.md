# Muscle memory outranks every other goal

**Picked, 2026-08-12:** the parity invariant is the top acceptance test, above every engine metric.
Key positions, hit areas, previews, drag-to-type, sounds, and the emoji pane must be
indistinguishable from stock.

**Rejected:** improving the keyboard's layout or feel anywhere, on any reasoning.

**Reason, in Jake's words:** "I've been typing with the Apple keyboard for years and my fingers
already move automatically to the keys, so I want the same exact keys covering the same exact areas
so I don't have to relearn where to press. If something changes and I suddenly have to press
somewhere else for a certain key, that would be very annoying."

The product is one change. Double-tapping the space bar inserts the punctuation the sentence calls
for. Everything else exists so a person can live on the keyboard daily without missing stock. A
second change is a reason to delete the app.

**What this constrains:**

- A loop that improves the punctuation engine while moving a key has failed, whatever its tests say.
- **The visible layer is the target; engine simulations are proxies.** Trace
  `2026-08-11-simulated-parity-while-visible-layer-unjudged` records the failure: a parity loop
  optimized simulated engine tests across sessions while the layer Jake judges by eye and thumb was
  never audited.
- The reference is the stock iOS keyboard itself, on-device, side by side. Not a screenshot, not a
  spec.
- The reverse-engineered visual constants live in the engine as tested data, in
  `specs/stock-design-parity.md` and `specs/stock-parity-test-matrix.md`. A constant is a measured
  value, not a guess that looked right.
- Scope stays on the one change. Languages, themes, and iPad stay out until the picture ships,
  decided 2026-08-12.

**The milestone order follows from this.** Parity is milestone 1: Jake types on it daily and never
notices a difference. Accuracy of the first pick is milestone 2, and its threshold was deliberately
deferred to that milestone's contract so the vision stays number-free.

**What would reopen it:** nothing while the goal is a keyboard someone switches to permanently. A
keyboard people must relearn does not get kept.
