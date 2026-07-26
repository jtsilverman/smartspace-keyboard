# Workplan

Phased build order. Units are commit-sized; status lives here. Phases 1-2 build today with the installed Swift CLI (`swift test`). Phase 3+ gates on Xcode + Apple Developer account.

## Phase 1 -- Punctuation engine (pure Swift package, no Xcode needed)

- [ ] 1.1 Git repo + `PunctuationEngine` Swift package scaffold, first failing test, `swift test` loop green on this Mac
- [ ] 1.2 Question detection: wh-words, auxiliary-first inversion with imperative disambiguation (aux + pronoun = question "do you want pizza"; aux + determiner/noun = command "do your homework"), trailing tags -> ranked candidates
- [ ] 1.3 Exclamation cues + default-period ranking
- [ ] 1.4 Abbreviation awareness (Mr/Dr/e.g.: period without sentence-end capitalization) + empty-context fallback to period
- [ ] 1.5 Cycle state machine: insert-then-cycle logic as pure testable state (candidate order, cycling window, wrap)
- [ ] 1.6 Triple-space ellipsis + no-double-punctuation guards
- [ ] 1.7 Corpus accuracy harness: labeled sentence set, accuracy as a test target; ship gate = top candidate matches label on >=90% of the corpus (also the bar future ML must beat)

## Phase 2 -- Typing engine logic (still off-device)

- [ ] 2.1 Autocorrect-lite pipeline as testable logic: word-boundary detection, correction decision rules, undo-tap protection (UITextChecker calls stubbed at the seam; real calls arrive in Phase 3)
- [ ] 2.2 Auto-capitalization + smart apostrophes + smart quotes/dashes rules
- [ ] 2.3 On-device stats counters model (counts only, no content)

**-- GATE: install Xcode (~15GB), enroll Apple Developer ($99/yr), iPhone available --**

## Phase 3 -- The keyboard (Xcode, simulator, then device)

- [ ] 3.1 App + keyboard extension scaffold; minimal QWERTY typing correctly in simulator. Includes the app-group probe: can the extension read app-group `UserDefaults` written by the host app WITHOUT Full Access on current iOS? (Apple's documented model gates shared containers behind Full Access; behavior is version-dependent.) If blocked: settings/stats UI moves into an in-keyboard panel and 4.2/4.3 shrink to onboarding-only host app.
- [ ] 3.2 Layers + keys: shift/caps, 123/symbols, long-press alternates, backspace repeat, return-key context
- [ ] 3.3 Wire hero feature: double/triple-space detection -> engine -> insert/cycle via textDocumentProxy; live-verify on real iPhone in Messages/Notes/Safari
- [ ] 3.4 Wire autocorrect-lite: real UITextChecker + UILexicon behind the Phase 2 seam; suggestion bar
- [ ] 3.5 Spacebar cursor drag, haptics, key-pop, light/dark
- [ ] 3.6 Emoji panel (search + recents)
- [ ] 3.7 Wire stats counters into live key events (increment on smart insert / cycle / keep; counts only, no content)

## Phase 4 -- Host app

- [ ] 4.1 Onboarding flow (guided enable, practice field with the aha moment)
- [ ] 4.2 Settings screen (candidate set, feature toggles) + extension-side consumption: each toggle read by the keyboard and branching to stock-equivalent behavior when off (transport per 3.1 probe outcome: app group or in-keyboard panel)
- [ ] 4.3 Stats screen

## Phase 5 -- Ship

- [ ] 5.1 TestFlight build on Jake's iPhone; live with it; iterate on engine accuracy from real annoyances
- [ ] 5.2 App Store metadata, privacy labels (nothing collected), screenshots, review notes
- [ ] 5.3 Submit; file Feedback Assistant enhancement request at Apple in parallel

## Standing rules

- One task per branch (`feat/<unit>`), PR to main, Jake merges. Full protocol: `~/.claude/rules/git-discipline.md`.
- Behavioral code lands RED -> GREEN (failing test committed first).
- Engine work never imports UIKit; the extension is a thin shell over tested logic (memory ceiling + testability both demand it).
