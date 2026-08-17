# Nothing leaves the device

**Picked:** the keyboard requests no Full Access, makes no network calls, and collects nothing.
Every computation is on-device.

**Rejected:** cloud AI, telemetry, auto-upload, and federated learning. All named as never, not
later.

**Reason:** two at once. "Your keystrokes never leave the device" is the privacy moat against a
category of apps people rightly distrust, and it is the App Review fast lane. A keyboard that asks
for Full Access has to earn a trust decision from every user at install.

**What this constrains:**

- **Full Access is never requested.** Apple gates the shared container between app and extension on
  it, so even settings and stats sharing may be blocked. `WORKPLAN.md` 3.1 probes it early, and the
  fallback is an in-keyboard settings panel. `app/Shared/AppGroupProbe.swift` is that probe.
- **The improvement loop stays local.** Every double-space self-labels: the mark the user finally
  keeps is ground truth. Text-free outcome records (rule fired, guess, kept mark, cycle taps) are
  always stored on-device and feed personal re-ranking, so a rule that fails for you gets demoted.
- **Raw capture is opt-in and off by default.** With the toggle on, the raw sentence and kept mark
  are stored locally behind a user-initiated export button. Jake, 2026-07-26.
- **Any future model is on-device.** The rules plateau is documented, and the remaining headroom
  belongs to a tiny on-device classifier, roughly 1 to 5MB, with Gboard as precedent. That size
  target exists because of the undocumented 30 to 77MB memory ceiling on keyboard extensions;
  overrunning it makes iOS kill the keyboard mid-typing.
- **Dictation is impossible, not deferred.** Apple blocks microphone access to keyboard extensions.

**Two platform limits shape the engine the same way:**

- A custom keyboard reads roughly the last sentence or two before the cursor through
  `documentContextBeforeInput`, and that is unreliable across apps. Prediction logic degrades to a
  plain period rather than guessing.
- There is no access to Apple's autocorrect dictionary. `UITextChecker` is the ceiling for v1 typing
  quality, which is why the typo benchmark scores against the real checker rather than an ideal one.

**What would reopen it:** nothing. Both the privacy claim and the review path depend on it, and the
export button already covers the one case where data needs to move, with the user pressing the
button.
