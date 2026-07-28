---
status: active
---

# Keyboard polish: cursor drag, haptics, key-pop, light/dark (WORKPLAN 3.5)

## Intent

Close the remaining feel gap with the stock Apple keyboard: long-press the spacebar and slide to move the cursor; keys give a light haptic tick and a magnified key-pop preview while touched; the keyboard follows the host field's light/dark appearance. All decision math (drag distance -> cursor steps) is a pure TypingEngine state machine; the extension translates gestures into `adjustTextPosition` calls.

## Acceptance criteria

1. Engine (`SpacebarCursorDrag`, pure, swift-test): dragging emits character-offset deltas of one per `stepWidth` points of horizontal travel, truncating toward zero (property: at any point in a move sequence, the sum of emitted deltas equals `Int((x - x0)/stepWidth)` — Swift truncation, so any sub-step movement in `(-stepWidth, stepWidth)` accumulates to 0); leftward travel past a full step emits negative deltas; a new drag starts fresh. `stepWidth` is a public constant (9.0 points) so the UI test derives drag distances from it.
2. Live (XCUITest): with `ab` in the field, long-press the spacebar and drag left by exactly `1.5 * SpacebarCursorDrag.stepWidth` points (one full step, deterministically short of two), release, then type `X`: the field reads `aXb` — the cursor genuinely moved before the insert.
3. A plain tap on space still inserts a space, and the double-space punctuation smoke assertions stay green (drag never fires `spaceTapped`).
4. Starting a cursor drag clears the SmartSpaceBar double-tap window and invalidates the autocorrect suggestion bar via a named `AutocorrectController.invalidateBar()` (cursor moved: pending undo/swap edits would target the wrong tail; `backspace()` delegates to it — engine test pins invalidateBar clearing the bar while protection survives).
8. Auto-shift re-arms from the new context when a drag ends (`armAutoShiftIfSentenceStart()`, same as every other cursor-moving action): drag the cursor to a sentence start and the next letter capitalizes.
5. Key-pop: touching a character key shows a magnified preview above it; it disappears on release AND on touch-cancel. Character keys only — deliberate stock-parity narrowing of UX.md's "every key press" wording (stock iOS does not magnify space/shift/return/backspace). Verified visually via simulator screenshot during a press (not XCTest-assertable; transient UI).
6. Light/dark: the keyboard's `overrideUserInterfaceStyle` follows `textDocumentProxy.keyboardAppearance` (`.dark` -> dark, `.light` -> light, `.default` -> unspecified), applied at appear and on `textDidChange`. Verified via simulator screenshot with a dark-appearance host field.
7. Haptics: light impact on key touch-down behind a single call site; keyboard extensions without Full Access may silently no-op — accepted, REAL-DEVICE verification rides the existing 3.3 device debt. Never requests Full Access.

## Non-goals

- Vertical drag line-jumping, hold-space input-mode switching, drag selection.
- Key sounds (`playInputClick`) — separate polish if Jake wants it.
- Settings toggles for haptics/appearance (4.2).
- Emoji panel (3.6).

## Orientation findings (compact)

- Space key: `keyButton(title: "space")` + `.touchUpInside -> spaceTapped` (KeyboardViewController.swift:161-163 post-3.4). No pan/long-press on it. A `UILongPressGestureRecognizer` (minimumPressDuration 0.4, matching the file's backspaceHeld/keyHeld convention) recognizing cancels the button's touch, so `touchUpInside` never fires for drags — AC3's mechanism, same precedent both existing recognizers rely on.
- Cursor moves: `textDocumentProxy.adjustTextPosition(byCharacterOffset:)`; apply per-delta during the drag.
- Bar interplay: on drag start call `spaceBar.nonSpaceKey()` + `autocorrect.backspace()` + `refreshSuggestionBar()` (AC4). `AutocorrectController.backspace()` already has the right semantics.
- Key-pop template: the alternates popup (`showAlternates`, floating UIStackView pinned above the button) is the structural precedent; key-pop is a single label version keyed to touchDown/touchUpInside/touchUpOutside/touchCancel/touchDragExit.
- Appearance: buttons use `.gray()` config + `.label` colors — they adapt automatically once `overrideUserInterfaceStyle` is set on `view`. `keyboardAppearance` read exists nowhere yet; hook `viewWillAppear` + `textDidChange(_:)`.
- Haptics: `UIImpactFeedbackGenerator` availability without Full Access is empirically uncertain in extensions; call is a safe no-op when unavailable. Simulator cannot produce haptics either way.
- No UIKit in engine; `SpacebarCursorDrag` joins SmartSpaceBar/AutocorrectController as pure state.
- Tests: engine `swift test`; app suite via xcodegen + xcodebuild on simulator DA42AC36 (DerivedData in scratchpad — iCloud xattr CodeSign failures otherwise).
- Branch stacked on `feat/autocorrect-wire` (PR #20 open); PR base = `feat/autocorrect-wire`, merge order noted in PR body.

## Design (creativity beat)

Alternatives: (a) UIPanGestureRecognizer with all math in the VC (untestable, braids gesture state with cursor math); (b) chosen — long-press recognizer drives a pure `SpacebarCursorDrag` struct (`begin(at:)`, `moved(to:) -> Int` returning the delta to apply now, `stepWidth` constant), VC applies deltas via `adjustTextPosition`; (c) 10x: full stock parity (vertical selection drag, trackpad mode on 3D touch) — out of scope, WORKPLAN names cursor drag only. Simplest viable: one struct, one gesture handler, three UI touches (pop, haptic, appearance) with no new state machines.

## Decomposition

1. RED: `SpacebarCursorDragTests` (deltas, truncation property, sub-step zero, negative travel, fresh-start) + `AutocorrectController.invalidateBar` test (bar clears, protection survives) — committed failing.
2. GREEN: `SpacebarCursorDrag` + `invalidateBar` in TypingEngine.
3. Wire: gesture on space + delta application + bar/window clearing + auto-shift re-arm on drag end (AC8); key-pop preview; haptic call; appearance following. New XCUITest for AC2/AC3; screenshots for AC5/AC6.
4. Review, fix, PR (base `feat/autocorrect-wire`).
