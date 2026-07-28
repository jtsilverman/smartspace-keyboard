# Workplan

Phased build order. Units are commit-sized; status lives here. Phases 1-2 build today with the installed Swift CLI (`swift test`). Phase 3+ gates on Xcode + Apple Developer account.

## Phase 1 -- Punctuation engine (pure Swift package, no Xcode needed)

- [x] 1.1 Git repo + `PunctuationEngine` Swift package scaffold, first failing test, `swift test` loop green on this Mac (engine/ package; RED 60da59a, GREEN 28f79ef)
- [x] 1.2 Question detection: wh-words, auxiliary-first inversion with imperative disambiguation (aux + pronoun = question "do you want pizza"; aux + determiner/noun = command "do your homework"), trailing tags -> ranked candidates
- [x] 1.2b Verb-first requests ("want to grab dinner", "wanna come") -- surfaced by the 1.2 live probe, not covered by aux-inversion
- [x] 1.3 Exclamation cues + default-period ranking
- [x] 1.4 Abbreviation awareness (Mr/Dr/e.g.: period without sentence-end capitalization; Candidate.endsSentence) + empty-context fallback to period
- [x] 1.5 Cycle state machine: insert-then-cycle logic as pure testable state (candidate order, cycling window, wrap)
- [x] 1.6 No-double-punctuation guard (empty candidates right after a terminal mark). Triple-space ellipsis DROPPED pending Jake: gesture conflicts with tap-to-cycle; recommended replacement is ellipsis as last cycle candidate
- [x] 1.7 Corpus accuracy harness, two sets: authored regression set (124, top-1 99%, gates 90/97) and FROZEN real-SMS eval (500 sender-labeled UCI sentences; baseline top-1 58%, top-2 80%; never edited alongside rule changes)
- [x] 1.8 Raise real-eval score via dev-miss patterns (dev 55->63; held-out test flat 61 -- hand rules near ceiling for ! )
- [x] 1.9 Continuation prediction: five-mark ranking; subordinate/conjunction/when-nonaux/greeting -> comma, say-verb/quote-noun -> opening quote. Dev 42->47/54->60; test 41->41/56->58 -- rule ceiling reached, remaining continuation headroom belongs to the ML phase

## Phase 2 -- Typing engine logic (still off-device)

- [x] 2.1 Autocorrect-lite pipeline as testable logic: word-boundary detection, correction decision rules, undo-tap protection (UITextChecker calls stubbed at the seam; real calls arrive in Phase 3). TypingEngine target: WordBoundary, CorrectionEngine + SpellChecking seam, CorrectionSession
- [x] 2.2 Auto-capitalization + smart apostrophes + smart quotes/dashes rules. CapitalizationRule (abbreviation-aware via public PunctuationEngine.isKnownAbbreviation), ContractionRule, SmartSymbols
- [x] 2.3 Outcome-record model (text-free: rule fired, guess, kept mark, cycle taps, length bucket) -- feeds stats screen AND personal re-ranking. Prediction/PredictionRule, OutcomeRecord, OutcomeStats
- [x] 2.4 Personal re-ranking: per-rule win/loss counters nudge candidate order (pure logic, testable). PersonalRanking: kept-mark counts per rule, 5-outcome threshold, stable reorder
- [x] 2.5 Opt-in capture + export format: raw sentence + kept mark stored locally when toggled on; export file becomes new frozen eval sets (and later ML training data). CaptureRecord + CaptureExport.tsv; storage/toggle wiring is Phase 3/4

**-- GATE: install Xcode (~15GB), enroll Apple Developer ($99/yr), iPhone available --**

## Phase 3 -- The keyboard (Xcode, simulator, then device)

- [x] 3.1 App + keyboard extension scaffold; minimal QWERTY typing correctly in simulator (letters, one-shot shift, space, return, backspace, globe). App-group probe verdict: AG:OK on simulator (iOS 26.5, no Full Access) -- PROVISIONAL, device re-probe rides 3.3; if device blocks: settings/stats UI moves into an in-keyboard panel and 4.2/4.3 shrink to onboarding-only host app. Verified by XCUITest smoke suite (EnableKeyboardTests + KeyboardSmokeTests) driving the real extension.
- [x] 3.2 Layers + keys: caps lock (double-tap) + auto-shift via CapitalizationRule, 123/#+= planes, long-press alternates, backspace repeat with acceleration, return-key context label. Pure state machines in TypingEngine (ShiftState v2, KeyboardLayer, ReturnKeyLabel); smoke test drives auto-shift/caps/123 live
- [x] 3.3 Wire hero feature: double-space -> engine -> insert/cycle via textDocumentProxy (SmartSpaceBar state machine; triple-space ellipsis stays dropped per 1.6). Simulator-verified end to end in the smoke test; REAL-IPHONE verification in Messages/Notes/Safari still owed (needs Apple Developer account + device)
- [x] 3.4 Wire autocorrect-lite: real UITextChecker + UILexicon behind the Phase 2 seam; suggestion bar. AutocorrectController (pure TypingEngine state machine) + 40pt bar above the keys: auto-apply top suggestion on space/return commit, slot-0 tap undoes + protects for the session, alternative tap swaps, backspace closes the undo window. Live-verified by AutocorrectBarTests in simulator; typo benchmark unchanged at 90% on the shared SystemSpellChecker.
- [x] 3.5 Spacebar cursor drag, haptics, key-pop, light/dark. SpacebarCursorDrag (pure 9pt-step math) drives adjustTextPosition from a long-press on space; per-button key-pop previews; light haptic every key (device verify owed with 3.3); overrideUserInterfaceStyle follows keyboardAppearance. Cursor drag live-verified (CursorDragTests); key-pop/dark verified by simulator screenshots.
- [x] 3.6 Emoji panel (search + recents). Emoji key opens tabs/grid panel (recents-first, 8 categories, curated ~300-emoji catalog); stock-style search mode: letters filter live in the query strip, result tap inserts. Pure EmojiCatalog/EmojiSearch/EmojiRecents in TypingEngine; recents persist via UserDefaults. Live-verified by EmojiPanelTests.
- [x] 3.7 Wire stats counters into live key events. OutcomeTracker lifecycle + capped OutcomeLog (2000, UserDefaults) record every double-space interaction (rule/guess/kept/taps/bucket, no text); PersonalRanking rebuilds from the log and reranks live candidates (2.4 wired here). Live-verified: outcome line observed for the smoke cycle sequence.

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
