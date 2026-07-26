# UX -- Functionality

How the keyboard behaves, in plain language. Not visual design (no colors, fonts, layouts here) -- what happens when you do things.

## Journey 1: install and first use

1. Download app from App Store, open it.
2. App walks through enabling: Settings > General > Keyboard > Keyboards > Add New Keyboard > SmartSpace. Two toggles, guided with screenshots. No "Allow Full Access" step -- we never ask for it.
3. In-app practice field: type a question, double-tap space, watch it insert `?`. The aha moment happens before you ever use it in Messages.
4. Switch to it anywhere via the globe key.

## Journey 2: the hero moment (daily typing)

- Type `want to grab dinner`, double-tap space -> `want to grab dinner? ` -- question detected (wh-word / verb-first / trailing tag heuristics).
- Type `i made it home`, double-tap space -> `i made it home. ` -- default period.
- Type `congrats on the offer`, double-tap space -> `congrats on the offer! ` -- exclamation cues.
- Guess wrong? Tap space once more: the inserted mark swaps to the next candidate in place (`?` -> `.` -> `!` -> wraps). No backspacing, no popup. Stop tapping when it's right; keep typing and the sentence continues normally.
- Triple-tap space -> `... `.
- Double-space right after existing `.` `?` `!` inserts nothing extra (never `?.`).
- If iOS gives us no sentence context (some apps truncate it), fall back to plain period -- exactly stock behavior, never worse.

## Journey 3: normal typing (table stakes behavior)

- Misspell a word, hit space: autocorrect-lite replaces it with Apple's top spelling suggestion; the suggestion bar (3 slots) shows alternatives; tap the original word in the bar to undo the correction.
- Contact names and your Settings text replacements are respected (never "corrected" away).
- Sentence starts and standalone `i` auto-capitalize. `dont` -> `don't` as you type.
- Hold backspace: deletes accelerate. Hold a letter: alternate characters (é, ñ) pop up.
- Press-and-slide on the space bar: cursor moves through text.
- Return key label matches context: Send in Messages, Search in Safari, Go in URL bars.
- `123` key opens numbers/symbols layer; emoji face key opens our emoji panel (search + recents).
- Every key press: haptic tick + visual key-pop. Keyboard follows system light/dark mode.
- Password fields: iOS automatically swaps back to the stock keyboard (system behavior; we're simply absent there).

## Journey 4: settings (in the host app)

- Punctuation candidates: toggle which marks double-space may choose from. Default on: `. ? !`. Available: `, : ; -`. Order of the cycle follows engine confidence, not a fixed list.
- Toggles: smart double-space (off = stock double-space-period), triple-space ellipsis, autocorrect, auto-capitalization, smart quotes/dashes, haptics.
- Everything works offline forever; there is no account, no sign-in, no sync.
- Fallback plan: if iOS blocks settings sharing between app and keyboard without the Full Access permission (open question, probed early in the build), settings and stats move into a panel opened from a gear key on the keyboard itself -- same functionality, different door. We never ask for Full Access either way.

## Journey 5: stats (host app, the shareable bit)

- "This week: 312 smart punctuations, 94% kept without cycling."
- Per-mark breakdown (how often `?` vs `!` vs `.`).
- Computed entirely on-device from counters the keyboard writes locally; no typed content is ever stored, only counts.

## Behavior rules (edge cases)

- Cycling window: tapping space cycles only while the punctuation just inserted is still adjacent to the cursor; type anything else and space returns to normal.
- Double-space mid-sentence after an abbreviation the engine knows (`Mr`, `Dr`, `e.g`) still inserts a period but does not treat it as sentence end for capitalization.
- Autocorrect never fires on the word being protected by an undo tap (no correction loops).
- All smart features individually degradable: any toggle off returns that behavior to stock-keyboard equivalent.
