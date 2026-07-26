---
status: active
---

# Smart Punctuation Keyboard (v1)

Live spec: intent, acceptance criteria, non-goals, research grounding. Feature tiers: `PRODUCT.md`. Behavior detail: `UX.md`. Build order + status: `WORKPLAN.md`.

## Intent

A full replacement iOS keyboard (App Store) whose hero feature is smart double-space: double-tapping the space bar inserts the most contextually appropriate punctuation for the sentence just typed, with tap-again-to-cycle recovery, plus enough table-stakes typing quality (autocorrect-lite via UITextChecker, auto-caps, cursor drag, emoji) that people can live on it daily. Apple locks the system keyboard, so a custom keyboard extension is the only path -- and a shipped App Store product with traction is also the only realistic route to Apple ever absorbing the feature into iOS.

## Acceptance criteria (v1)

1. `how are you` + double-space -> `how are you? ` (question cues: wh-words, auxiliary-first inversion, trailing tags).
2. `i went to the store` + double-space -> `i went to the store. ` (default).
3. `congrats on the new job` + double-space -> `congrats on the new job! ` (exclamation cues).
4. Tapping space again after an insert replaces the mark with the next ranked candidate in place, never appending; cycling stops once anything else is typed.
5. Triple-space inserts `... `; double-space directly after existing terminal punctuation inserts nothing extra.
6. Empty/unavailable sentence context falls back to plain period -- stock behavior, never worse. The period fallback applies even if `.` is disabled as a cycle candidate (disabling `.` only removes it from context-ranked cycling).
7. Candidate set is user-configurable (default `. ? !`; optional `, : ; -`); every smart feature toggles off to stock-equivalent behavior.
7b. Double-space after a known abbreviation (`Mr`, `Dr`, `e.g`) inserts a period without triggering sentence-start auto-capitalization of the next word.
7c. Ship gate: the engine's top candidate matches the label on >=90% of the labeled corpus (WORKPLAN 1.7); measured, not eyeballed, before 5.1.
8. Misspelled word + space is corrected via UITextChecker's top suggestion; suggestion bar offers alternatives; tapping the original undoes and protects the word from re-correction. UILexicon entries (contacts, text replacements) are never corrected away.
9. Auto-capitalization (sentence start, i -> I) and smart apostrophes (dont -> don't) work as typed.
10. All punctuation/correction decisions come from pure Swift packages with a `swift test` suite covering 1-9 plus a labeled-corpus accuracy harness; decisions are synchronous, on-device, no network.
11. The keyboard extension types correctly in Messages/Notes/Safari on a real iPhone: QWERTY, shift/caps, number/symbol layers, long-press alternates, backspace repeat, spacebar cursor drag, context-aware return key, haptics, light/dark, emoji panel.
12. Extension never requests Full Access; App Store privacy label reads "no data collected."

## Non-goals (v1)

- Autocorrect parity with stock QuickType (UITextChecker is the v1 ceiling; no custom prediction/learning).
- ML model (rules first; the corpus harness in WORKPLAN 1.5 is the on-ramp and the bar).
- Swipe typing, languages beyond English, iPad-optimized layouts, themes.
- Cloud/network anything, analytics, accounts. Dictation (Apple blocks mic access, hard stop).
- Colon/semicolon/dash candidates (faded per EVAL.md until export data shows usage). Comma and opening-quote prediction ARE in scope (WORKPLAN 1.9) -- continuation marks graduated from non-goal when the eval charter made them benchmark marks.

## Orientation findings (deep-research 2026-07-25, adversarially verified)

- System keyboard is Apple-locked: binary `.` Shortcut toggle only; no API/Shortcut/accessibility/profile path; custom keyboard extension (`UIInputViewController` + `textDocumentProxy`) is the only mechanism. High confidence, cross-verified.
- `documentContextBeforeInput` typically returns ~the last sentence or two, varies by host app, unreliable after paste -> criterion 6.
- Memory ceiling undocumented, community-reported ~30-77MB, overrun = silent kill -> keep the extension a thin shell over the packages; matters more when ML arrives.
- `UITextChecker` + `UILexicon` ARE available to extensions (basis of autocorrect-lite); Apple's QuickType dictionary/predictions are not. No mic. Secure fields auto-swap to stock keyboard.
- Full Access gates network, pasteboard, AND (per Apple's documented model) the shared container with the host app. v1 needs no network/pasteboard, but app-group settings/stats sharing is at risk: whether app-group `UserDefaults` reads work without Full Access on current iOS is version-dependent and UNVERIFIED -- probed live in WORKPLAN 3.1, with the in-keyboard settings panel as the designed fallback. "Never requests Full Access" stays a hard requirement either way.
- Prior-art gap confirmed: no shipping keyboard or OSS project does context-aware double-space punctuation.
- KeyboardKit is NOT open source despite MIT badges (LICENSE fetched primary-source: closed, paid key + written agreement). Build from scratch on Apple APIs. Scribe-iOS is GPL-3.0: reference reading only.
- Gboard iOS frozen since 2022; SwiftKey alive but no smart double-space. On-device ML precedent: Gboard ships ~1.4MB quantized next-word model.
- Toolchain: this Mac has Swift 6.0.3 CLI, no Xcode. WORKPLAN Phases 1-2 build today; Phase 3+ gates on Xcode + Apple Developer account ($99/yr) + physical iPhone.

## Decisions log

- App Store product, not personal tool (Jake, 2026-07-25).
- Wrong-guess recovery: best-guess insert + tap-space-to-cycle, no picker UI (Jake, 2026-07-25).
- Autocorrect-lite in v1 scope -- "best of both worlds" resolution to the typing-quality gap (2026-07-25).
- Candidate set user-configurable, `. ? !` default on, `, : ; -` optional (Jake, 2026-07-25).
- From-scratch on Apple APIs; KeyboardKit rejected on verified license grounds (2026-07-25).
- Strategy: ship + traction as the pitch to Apple; Feedback Assistant request filed in parallel; never email ideas (unsolicited-idea policy) (2026-07-25).
- Engine is pure rules for v1, no LLM (memory ceiling + no-network are hard constraints); the 1.7 corpus referees when rules plateau and a tiny on-device classifier (~1-5MB, Gboard precedent) graduates in (2026-07-26).
- Quotes: SUPERSEDED same day -- opening quote joined the benchmark as a continuation mark (Jake); closing-quote-as-sentence-ender stays out; smart quote pairing stays v1 (2026-07-26).
- Eval charter locked in EVAL.md: benchmark marks are . ? ! , " (comma and opening quote = continuation predictions, self-labeled from real SMS); : ; - faded until export data shows usage; real set v2.1 is 638 rows dev/test split (Jake, 2026-07-26).
