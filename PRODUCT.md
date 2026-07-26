# SmartSpace (working name -- rename freely)

A full replacement iOS keyboard whose identity is **punctuation that thinks**: double-tapping the space bar inserts the most contextually appropriate punctuation for the sentence, not always a period. Everything else about the keyboard exists so people can live on it daily without missing the stock keyboard.

## Why this exists

- The stock iPhone double-space-period is dumb: "how are you" + double-space gives "how are you. " when it obviously should be "?". Apple offers only an on/off toggle, and locks the system keyboard against any third-party modification (verified 2026-07-25, see specs/smart-punctuation-keyboard.md orientation findings).
- Nobody else does this. Every shipping keyboard (Gboard, SwiftKey, Grammarly, the 2026 AI-keyboard wave) either copies the fixed period behavior or bolts on post-hoc AI rewriting. Context-aware double-space is an open lane.
- Endgame: ship on the App Store, prove demand. The historically proven route to getting a feature into iOS itself is a shipped product Apple absorbs or acquires (f.lux -> Night Shift, Workflow -> Shortcuts). The app is both the product and the pitch. A Feedback Assistant enhancement request gets filed in parallel (free, low odds, costs nothing).

## The hero feature

Double-space inserts the best sentence-ending punctuation based on the sentence typed so far. If the guess is wrong, tapping space again cycles to the next candidate in place -- no backspacing, no picker UI. Candidate set is user-configurable (`. ? !` on by default; `, : ; -` available in settings). Triple-space gives ellipsis.

## Feature tiers

**Table stakes (v1)** -- without these the keyboard gets deleted:
- Autocorrect-lite + 3-slot suggestion bar (Apple's `UITextChecker` spell engine + `UILexicon` contacts/text-replacements)
- Auto-capitalization (sentence start, i -> I), smart apostrophes (dont -> don't)
- Number/symbol layers, long-press alternate characters
- Spacebar-drag cursor movement
- Backspace hold-to-repeat, haptics + key-pop preview, light/dark mode
- Context-aware return key (Send/Go/Search)
- Custom emoji panel (extensions cannot open the system emoji keyboard)

**The brand (v1)** -- what makes it not just another keyboard:
- Smart double-space + tap-to-cycle (hero)
- Configurable punctuation candidate set
- Triple-space ellipsis
- Smart quotes and dashes done right
- Punctuation stats in the host app ("your keyboard chose ? correctly 94% this week") -- all computed on-device

**Later (v2+)**:
- Sentence backcheck at double-space: when the sentence completes, re-check top confusable pairs (were/we're, its/it's, your/you're, their/there) against the now-full sentence via Apple's on-device part-of-speech tagger (`NLTagger`). Fixes the class of error stock autocorrect gets wrong because it commits word-by-word; we already analyze the full sentence at exactly that moment (Jake, 2026-07-26).
- Continuation predictions: when context says the sentence isn't ending, double-space predicts what starts next instead -- e.g. `he said` -> space + opening quote (Jake, 2026-07-26). Extends the engine's candidate type from "sentence enders" to "what comes next."
- Tiny on-device CoreML model replacing/augmenting the rules (mid-sentence commas, tone awareness)
- Swipe typing (biggest missing table stake; a full ML project on its own)
- Languages beyond English

**Never**:
- Cloud AI / network anything. The keyboard requests no Full Access, makes no network calls, collects nothing. "Your keystrokes never leave the device" is the privacy moat and the App Review fast lane.
- Dictation (Apple blocks microphone access to keyboard extensions, hard stop).

## Constraints that shape everything

- Custom keyboards read only ~the last sentence or two before the cursor (`documentContextBeforeInput`, unreliable across apps) -- prediction logic must degrade to plain period gracefully.
- Undocumented memory ceiling ~30-77MB; overrun = iOS silently kills the keyboard mid-typing. Rules engine is trivial against it; matters when ML arrives.
- Secure/password fields auto-swap back to the stock keyboard (iOS behavior, not ours).
- No Apple autocorrect dictionary access; `UITextChecker` is the ceiling for v1 typing quality.
- Full Access also gates the shared container between app and keyboard per Apple's documented model -- so even settings/stats sharing may be blocked without it. Probed early (WORKPLAN 3.1); fallback is an in-keyboard settings panel. Never requesting Full Access is non-negotiable.

## Prerequisites to ship

- Apple Developer account, $99/yr (developer.apple.com/programs) -- needed at TestFlight stage
- Xcode (~15GB, free) on this Mac -- needed for the keyboard extension; the punctuation engine builds today with the Swift CLI already installed
- Jake's iPhone for real-device testing

## Doc map

- `UX.md` -- what it looks and feels like, plain language
- `WORKPLAN.md` -- phased build order and status
- `specs/smart-punctuation-keyboard.md` -- live spec: intent, acceptance criteria, non-goals, research findings
