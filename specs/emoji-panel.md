---
status: active
---

# Emoji panel: categories, recents, search (WORKPLAN 3.6)

## Intent

An emoji key on the bottom row opens a stock-style emoji panel in place of the letter rows: category tabs (recents first), a scrollable grid, and search. Search works the way the stock keyboard's does — entering search mode brings the letter keys back with a query strip where the suggestion bar sits; typing filters emoji live; tapping a result inserts it. Selection logic (search matching, recents MRU) is pure TypingEngine state; the extension renders grids and routes key taps.

## Acceptance criteria

1. Engine `EmojiRecents` (swift-test): recording an emoji puts it at the front, re-recording moves it (no duplicates), the list caps at 30, and it round-trips through an injected storage seam (protocol; UserDefaults in the extension).
2. Engine `EmojiSearch` (swift-test): case-insensitive match on name/keywords ("heart" finds ❤️, "dog" finds 🐶); results ordered name-prefix matches before keyword matches; empty/whitespace query returns nothing; result count capped at 24.
3. Engine `EmojiCatalog` (swift-test): every entry has non-empty emoji + name + category; each of the 8 categories is non-empty; no duplicate emoji.
4. Live (XCUITest): tapping the emoji key (`emoji-key`) swaps the letter rows for the panel; tapping the 😀 grid cell (identifier `emoji-item-😀` — cells get synthetic identifiers, same reasoning as `suggestion-N`: emoji-only button labels surface as spoken names, not glyphs) inserts 😀 into the field; tapping `emoji-abc` restores letters and typing still works.
5. Live (XCUITest): after inserting 😀, closing and reopening the panel shows 😀 as the first cell of the Recents tab (`emoji-cat-recents`).
6. Category tabs (`emoji-cat-<name>`) switch the visible grid to that category's emoji. Tab row layout: `[emoji-search 🔍][emoji-cat-recents][8 category tabs]` — search entry is a permanent leftmost tab.
7. Live (XCUITest): in search mode (entered via the `emoji-search` tab), tapping letter keys types into the query strip instead of the document (field text unchanged), matching emoji appear in the strip, tapping one inserts it into the document and exits search; `emoji-search-cancel` exits without inserting; backspace edits the query, and when the query is empty the document is untouched by backspace. Search-mode handler contract: `characterTapped` keeps `dismissAlternates()` + `spaceBar.nonSpaceKey()` but skips shift consumption (query is case-insensitive, appended lowercase) and never calls `insertText`; `backspaceTapped` only pops the query — no `deleteBackward`, no `autocorrect.backspace()`, no `armAutoShiftIfSentenceStart()` (those act on the document, which search does not touch).
8. Emoji interactions call `spaceBar.nonSpaceKey()` (an emoji tap or panel toggle is a non-space key: the double-tap window closes); the autocorrect session is untouched. Bar interplay: a visible correction bar STAYS while the plain panel is open (its undo target is still the document tail); ENTERING search invalidates it (`autocorrect.invalidateBar()`) because the query strip takes over that surface.
9. Full simulator suite green (existing smoke/autocorrect/cursor tests unchanged and passing).

## Non-goals

- Full Unicode coverage: a curated ~300-emoji catalog ships (generated file, one entry per line); the long tail can grow later without structural change.
- Skin-tone variants, long-press emoji alternates.
- Frequency-weighted recents ordering (pure MRU only).
- App-group sharing of recents (extension-local UserDefaults).
- Word-to-emoji suggestions in the autocorrect bar.

## Orientation findings (compact)

- Bottom row build: `rebuildRows()` bottom row is `[123][🌐][space][return]` with width multipliers (KeyboardViewController.swift). Emoji key becomes a 5th button (0.12 width) between 123 and 🌐; stock parity puts it left of dictation, ours sits left of globe.
- Panel swap: the panel does NOT reuse `rowsStack` (its `fillEqually` distribution would give tabs/grid/bottom-row equal 72pt slices). A dedicated `emojiPanel` container sits in the same frame (pinned to `rowsStack`'s edges); `rowsStack.isHidden` toggles with it. Internal layout is explicit: tabs row 36pt, bottom row ([emoji-abc][space][return]) 44pt, grid scroll takes the remainder (~128pt viewport, vertically scrollable). No KeyboardLayer change: the layer enum stays letters/numbers/symbols (panel is a VC presentation mode, not a plane).
- Search mode: `emojiSearchActive` + `searchQuery` in the VC; when active, `characterTapped` routes the title into the query (no `insertText`), `backspaceTapped` pops the query, and the suggestion-bar strip area renders query + results. Exits: result tap, cancel, emoji-abc.
- Recents persistence: extension sandbox `UserDefaults.standard` persists across keyboard sessions; seam `EmojiRecentsStore` protocol so engine tests use an in-memory fake (engine cannot import Foundation UserDefaults? Foundation is fine in the engine package — but keep the seam so tests control state and the engine stays storage-agnostic).
- SmartSpaceBar: any panel interaction calls `nonSpaceKey()` (matches every other non-space key path).
- Suite: engine `swift test`; app via xcodegen + xcodebuild, DerivedData in scratchpad. UI tests use accessibility identifiers (precedent: suggestion-0/1/2).

## Design (creativity beat)

Alternatives: (a) emoji as a 4th KeyboardLayer plane rendered through `characterButton` (wrong shape: grids, tabs, and search do not fit the uniform key-row model and would braid panel state into the layer machine); (b) chosen — panel as a VC presentation mode over pure `EmojiSearch`/`EmojiRecents`/`EmojiCatalog` engine types; (c) 10x: full stock parity (skin tones, frequency ranking, word suggestions) — non-goals. Simplest viable: three small engine types + one panel builder + a search reroute flag.

## Decomposition

1. RED: `EmojiRecentsTests`, `EmojiSearchTests`, `EmojiCatalogTests` — committed failing.
2. GREEN: `EmojiCatalog` (curated generated file), `EmojiSearch`, `EmojiRecents` in TypingEngine.
3. Wire: emoji key + panel (tabs/grid/recents) + search mode reroute; `EmojiPanelTests` XCUITest for AC4-AC7. Full suite green.
4. Review, fix, PR (base `feat/keyboard-polish`).
