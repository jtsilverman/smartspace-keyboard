# Eval Charter

The benchmark every engine change (rules today, model later) is judged against. Intentional, not exhaustive: it covers the marks and variance users actually produce in texting, and nothing else until usage data says otherwise.

## Marks in scope

- `.` `?` `!` `,` -- the four texting workhorses. Comma is "the sentence continues here": a real double-space intent mid-sentence.
- Deferred (`: ; -` and `"`): rare in texting relative to the four, and each extra cycle candidate makes recovery slower. Revisit if opt-in export data shows real usage (Jake, 2026-07-26).

## Variance axes the set must cover

1. Register: full grammar ("what time does it start") vs txt shorthand ("wat u doing", "r u") vs dropped pronouns ("coming tonight", "done with the car").
2. Sentence type: statement, wh-question, yes-no question, tag question, imperative, exclamation/greeting, mid-sentence continuation (comma).
3. Length: 1-2 word fragments ("you up") through normal sentences.
4. Ambiguity: entries where two marks are defensible belong in the set; top-2 is their metric (best-guess + one cycle tap is the product experience).

## Sets and rules

- **Real set** (`RealCorpus.swift`): sentences from the UCI SMS Spam Collection (ham only) whose senders typed the mark themselves; the mark is the label. Comma rows are text-before-a-comma inside real messages. Stratified so ? ! , have signal; natural texting is ~2/3 periods, so real-world scores skew higher than benchmark scores.
  - Split into dev (misses may be studied) and held-out test (aggregate score only, never inspect sentences). Dev-only gains = overfitting, caught by design.
  - FROZEN: sentences never edited in a change that also touches engine code. Regeneration/expansion is its own commit, rules untouched.
- **Authored set** (`Corpus.swift`): written by us for coverage the real set lacks and as adversarial guards for every rule. Regression suite with hard gates (top-1 >= 90%, top-2 >= 97%), not the headline number.
- **Future**: opt-in export data becomes new frozen real sets (and ML training data -- training rows and eval rows never overlap).

## Metrics

- Top-1: right on the first guess. Top-2: right within one cycle tap -- the product-truth metric.
- Reported per label (aggregate only for the test half). A change that lifts one mark by tanking another is visible, not averaged away.

## Known blind spots (accepted, revisit with export data)

2000s UK/Singapore SMS idiom; no emoji; no conversation-history context; senders who never punctuate are unrepresented; comma labels only exist where senders punctuated mid-sentence.
