---
status: active
---
# Stock pixel parity

Serves `specs/vision.md`. Every check below cites the vision milestone it serves.

## Intent

Jake's thumbs must land where they land on the stock keyboard, on every iPhone he can hold. Today
they do not on the big phones: SmartSpace lays out the 402pt geometry everywhere, so on a 16 Plus,
16 Pro Max, 17 Pro Max or Air every key row sits 10pt low and every cap is 2pt short. On every
device the strip above the keys is 10pt taller than stock's, and the function keys (shift, delete,
123, emoji, return) are painted blue-grey where iOS 26 paints them white. This task makes the
rendered keyboard match the stock keyboard on all nine iPhone 16 and 17 simulators, measured from
screenshots, not from the accessibility tree.

Matching the picture is half of it. Jake's thumbs also have to land on the same letter, so this task
carries the mechanics too: every point inside the keyboard belongs to the same key it belongs to on
stock, including the grey between the caps, and pressing a key raises the same preview and supports
the same spacebar drag. A keyboard that photographs identically and answers a gutter press with the
neighbouring letter has failed the invariant.

## Non-goals

- iPad, landscape, external keyboards, languages beyond en-US.
- Apple's context-dependent hit bias, where the letter-bigram prior grows the likely next key. The
  probe measures the neutral, empty-context boundary; `BiasedKeyResolver` owns the prior and stays
  as it is.
- Swipe typing.
- The emoji panel's internal grid; only its key on the bottom row is in scope.
- The globe and dictation controls. They are system-drawn and already report identical frames.
- The punctuation engine, autocorrect, and candidate ranking. Mechanics here means touch, preview
  and drag, never what the keyboard decides to type.

## Orientation

- `engine/Sources/TypingEngine/StockLayoutMetrics.swift` holds the geometry: `rowPitch = 54`,
  `keyAreaHeight = 216`, `capInsetTop = 1`, `capInsetBottom = 10`, `capCornerRadius = 5`, and a
  `FunctionKeys` struct that scales the 402pt constants by `width / 402`. Widths scale; the row
  pitch and cap height do not.
- `app/SmartSpaceKeyboard/KeyboardViewController.swift:204` pins the candidate bar at 44pt and
  anchors the key rows to its bottom (`:209`), with the rows fixed to
  `StockLayoutMetrics.keyAreaHeight` (`:214`).
- `engine/Sources/TypingEngine/KeyTheme.swift` holds `StockKeyTheme`, the fills the controller and
  `KeyPopView` paint from.
- `engine/Tests/TypingEngineTests/StockLayoutMetricsTests.swift` asserts the measured 402pt oracle
  and is the pattern the new device class follows.
- `app/SmartSpaceUITests/ParityShotTests.swift` is the capture harness written 2026-08-18; the
  analysis scripts live in the session scratchpad and move into `eval/parity/` as unit 4.
- Brain: `wiki/patterns/ios-xcode-swift.md` warns that AX frames measure the touch cell, not the
  visible cap, so a keyboard passes AX metrics while looking wrong. Every number below comes from a
  pixel scan. Grep of `wiki/` and `sources/` for prior parity research returned one unrelated hit.

### The measured oracle (2026-08-18, iOS 26.3.1, nine simulators)

| Width class | Devices | Row pitch | Cap height | Bar band |
|---|---|---|---|---|
| 390 to 402pt | 16, 16e, 16 Pro, 17, 17 Pro | 54pt | 43pt | 50.3pt |
| 420 to 440pt | Air, 16 Plus, 16 Pro Max, 17 Pro Max | 56pt | 45pt | 50.3pt |

SmartSpace today: 54pt pitch and 43pt caps everywhere, 60.3pt bar band everywhere, function fill
`174,179,188` against stock's `255,255,255`.

## GOAL

On every iPhone 16 and 17 simulator, a screenshot of SmartSpace laid over a screenshot of the stock
keyboard shows the keys in the same places at the same sizes: same row heights, same cap sizes, the
same distance from the top of the keyboard to the first row of keys, and the function keys the same
white as Apple's. Jake can flip between the two screenshots and see the keys hold still. Pressing
any point on either keyboard, including the grey between the caps, types the same letter on both,
and a press raises the same preview bubble while a drag along the space bar moves the cursor the
same way.

## CHECKS

Derived, not Jake-facing. Each check cites the vision milestone it serves.

1. **vision:1** -- Row pitch and cap height match stock per width class (54/43 at or below 402pt,
   56/45 at or above 420pt) within 1pt, measured by the pixel scan on all nine devices:
   `eval/parity/run-all.sh`.
2. **vision:1** -- The bar band, the distance from the top of the keyboard assembly to the top of
   the first key row, is 50.3pt within 1pt on all nine devices, same command.
3. **vision:1** -- Every letter cap sits within 1pt of its stock counterpart in x, y, width and
   height, and the space bar within 1pt, on all nine devices, same command.
4. **vision:1** -- The fill of shift, delete, 123, emoji and return matches stock within 4 of 255
   per channel on all nine devices, same command.
5. **vision:1** -- Hit boundaries match: a tap-probe walks each row of both keyboards, bisecting
   between neighbouring key centres, and every measured boundary lands within 1pt of stock's, with
   no probe point on either keyboard producing no character: `eval/parity/probe-boundaries.sh`.
6. **vision:1** -- Mechanics match on a probe run: a press raises the preview bubble over the same
   key, and a spacebar drag of a given distance moves the cursor the same number of characters as
   stock.
7. **vision:1** -- The run reports nine devices measured and zero skipped, `swift test` carries the
   large-class oracle at 420, 430 and 440pt, and the suites in `docs/runbooks/build-and-eval.md`
   pass with no regression.

## LOOP

/loop Read specs/vision.md, then specs/stock-pixel-parity.md. Work on branch feat/stock-pixel-parity. Close the next open check: write the failing test first, make it pass, then re-run the parity capture and paste the measured numbers. Report progress as vision milestones satisfied.
STOP when every check is true, `eval/parity/run-all.sh` reports nine devices within tolerance, and
`agents/vision-auditor.md` returns MATCHES on milestone 1.

## Decisions

| Decision | Reason |
| Width class is a step, not a scale | Stock measures 54/43 at 390, 393 and 402pt, then 56/45 at 420, 430 and 440pt. A linear scale by width fits neither group. |
| Pixel scan is the oracle | AX frames report touch cells for stock and visible caps for SmartSpace, so the two are not comparable (`wiki/patterns/ios-xcode-swift.md`). |
| Harness stays a harness | The capture drives two keyboards and nine simulators; it lives in `eval/parity/`, run on demand, not in the per-commit suite. |
| Geometry lands before the probe | A boundary measured against a misplaced cap measures nothing. Units 1 to 3 run first, then the probe. |
| Probe measures empty context | Apple's hit targets move with the letter-bigram prior, so a neutral field is the only stable oracle. |

## Progress

- [ ] 1 Large-class geometry: `StockLayoutMetrics` gains the width class, tests at 420/430/440pt
- [ ] 2 Bar band: the strip above the keys drops to 50.3pt
- [ ] 3 Function-key fill: `StockKeyTheme` paints shift, delete, 123, emoji and return stock white
- [ ] 4 Harness lands in `eval/parity/` and reports all nine devices
- [ ] 5 Boundary probe: tap-bisect both keyboards, diff the boundaries, fix `KeyZoneMap` to match
- [ ] 6 Mechanics: preview bubble and spacebar drag probed against stock
