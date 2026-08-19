# docs/

The four kinds of doc a session reads to learn SmartSpace's current shape: architecture,
conventions, runbooks, decisions. Six files, because the project has three decisions worth
recording.

| File | Question it answers |
|---|---|
| `architecture/two-layers.md` | The Swift package and the Xcode app, what each owns, what runs without Xcode |
| `conventions/code-and-tests.md` | Where a test goes, the corpus rules, the invariant-first fix rule, git naming |
| `runbooks/build-and-eval.md` | Run the engine tests, regenerate the Xcode project, run on device, score a corpus |
| `decisions/muscle-memory-outranks-everything.md` | Why stock parity beats every other goal |
| `decisions/frozen-blind-corpora.md` | Why eval rows are authored blind and never change beside engine source |
| `decisions/nothing-leaves-the-device.md` | Why there is no network, no Full Access, and no cloud |

The root docs are the product layer. `specs/vision.md` is the epic and injects every session.
`PRODUCT.md` holds the feature tiers and the constraints. `UX.md` is the plain-language feel.
`WORKPLAN.md` is the phased build order and the live status. `EVAL.md` is the benchmark charter.
These docs point at those rather than restating them.
