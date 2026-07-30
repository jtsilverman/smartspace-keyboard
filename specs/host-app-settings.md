---
status: active
---

# Settings screen + extension consumption (WORKPLAN 4.2)

## Intent

The host app gets a settings screen whose toggles the keyboard actually obeys: feature switches (smart double-space, autocorrect, auto-capitalization, smart quotes/dashes, haptics) and the punctuation candidate set (`. ? !` on by default; `, : ; -` optional), written to the app-group `UserDefaults` (`group.com.jtsilverman.smartspace`, AG:OK per the 3.1 probe) and read by the extension on every keyboard load, with each feature branching to stock-equivalent behavior when off. This is the transport 4.3 (stats) reuses.

## Acceptance criteria

1. Engine (swift test): a pure `KeyboardSettings` model in TypingEngine decodes from an injected key-value store (same seam pattern as `EmojiRecents`/`OutcomeLog`): empty store yields defaults (all features on, candidates `. ? !`), stored overrides round-trip, unknown/corrupt values degrade to defaults per-key (never crash, never all-or-nothing).
2. Engine: the candidate set filters `PunctuationEngine` output without reordering it (order stays engine confidence); disabling a mark removes it from double-space candidates and cycling.
3. Extension: each toggle off produces stock behavior — smart double-space off = double-space inserts two spaces (stock period-shortcut untouched by us); autocorrect off = no auto-replace, no suggestion bar; auto-cap off = shift only manual; smart symbols off = straight quotes/hyphens as typed; haptics off = no impact feedback. XCUITest covers smart double-space off and autocorrect off (the two observable in the practice field); the rest verified at the engine/branch level.
4. App: a SwiftUI settings screen writes the same keys to the app-group defaults; toggling in the app changes keyboard behavior on next keyboard appearance (one XCUITest: toggle smart double-space off in app, switch to practice field, double-space yields no smart mark).
5. Settings default-on: a fresh install with no writes behaves exactly as today (all Phase 3 behavior unchanged; full existing suite green).

## Non-goals

- Stats screen (4.3) and onboarding (4.1).
- Triple-space ellipsis toggle: the feature stays dropped (WORKPLAN 1.6/3.3); UX.md Journey 4 lists it, but there is nothing to toggle. UX.md updated when this ships.
- Live re-read mid-session (settings apply on keyboard load; stock keyboards behave the same).
- In-keyboard settings panel fallback (only if device probe later fails; simulator AG:OK stands).

## Progress

- [x] Spec drafted; pending Jake sign-off on intent/acceptance/non-goals
- [x] Unit A: `KeyboardSettings` pure model + store seam (RED+GREEN, swift test)
- [ ] Unit B: candidate-set filtering into SmartSpaceBar/prediction path
- [ ] Unit C: extension consumption branches (each feature's off-path)
- [ ] Unit D: SwiftUI settings screen writing app-group defaults
- [ ] Unit E: live XCUITest (app toggle -> keyboard behavior) + full suite
