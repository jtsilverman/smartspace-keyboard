#!/usr/bin/env python3
"""Every one-key slip of every common word, from the stock key geometry
(specs/autocorrect-loop.md, unit 3).

    python3 eval/slips/gen_slips.py [--top N]

Writes:
    eval/slips/slips.tsv            id  kind  intended  typed      the whole corpus
    eval/slips/adjacency.tsv        letter  neighbours             pinned by KeyNeighborsPinTests
    eval/oracle/corpus/slips.tsv    id  slice  typed  offsets  note  150 rows for the stock recorder

Five kinds, one slip each: `neighbor` swaps a letter for a key that touches
it, `drop` loses a letter, `double` doubles one, `swap` transposes two that
sit together, `split` puts a stray space inside the word. A slip that is
itself a word ("cat" -> "car") is left out: nothing can fix it without
context, and it would count as a miss for both stock and us.

Deterministic: one seed, no clock, so a regeneration reproduces every file
byte for byte. That is what freezes the recorded sample.
"""
import argparse
import csv
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "engine" / "tools"))
import wordlist  # noqa: E402

OUT = ROOT / "eval" / "slips"
SAMPLE = ROOT / "eval" / "oracle" / "corpus" / "slips.tsv"
SEED = 20260912
KINDS = ("neighbor", "drop", "double", "swap", "split")

# The stock letter grid at the 402pt device class (StockLayoutMetrics): ten
# cells across, a 9-key row indented half a cell, the 7-key row set in past
# the shift key. Rows are 54pt, cells (402 - 2 * 3.67) / 10 wide.
ROWS = ("qwertyuiop", "asdfghjkl", "zxcvbnm")
WIDTH, SIDE_INSET, ROW_PITCH = 402.0, 3.67, 54.0
PITCH = (WIDTH - 2 * SIDE_INSET) / 10
SHIFT_WIDTH, ROW3_GAP = 51.33, 7.67
# Neighbours sit within 1.45 cells, each axis scaled by its own pitch, the
# same rule KeyNeighbors applies (a full diagonal step is 1.41, two keys
# along a row 2.0).
REACH = 1.45


def _centres() -> dict:
    out = {}
    for index, keys in enumerate(ROWS):
        if index == 2:
            x0 = SIDE_INSET + SHIFT_WIDTH + ROW3_GAP
        else:
            x0 = SIDE_INSET + (PITCH / 2 if len(keys) == 9 else 0)
        for i, key in enumerate(keys):
            out[key] = (x0 + i * PITCH + PITCH / 2, index * ROW_PITCH + ROW_PITCH / 2)
    return out


CENTRES = _centres()


def neighbours(letter: str) -> set:
    """The letters whose keys touch this one. A letter is not its own neighbour."""
    x, y = CENTRES[letter]
    return {
        other for other, (ox, oy) in CENTRES.items()
        if other != letter
        and math.hypot((x - ox) / PITCH, (y - oy) / ROW_PITCH) <= REACH
    }


def slips(word: str):
    """(kind, typed) for every single slip of `word`, no repeats."""
    seen = set()
    n = len(word)
    for i, ch in enumerate(word):
        for other in sorted(neighbours(ch)):
            yield from _one(seen, word, "neighbor", word[:i] + other + word[i + 1:])
    for i in range(n):
        yield from _one(seen, word, "drop", word[:i] + word[i + 1:])
    for i in range(n):
        yield from _one(seen, word, "double", word[:i + 1] + word[i] + word[i + 1:])
    for i in range(n - 1):
        yield from _one(seen, word, "swap", word[:i] + word[i + 1] + word[i] + word[i + 2:])
    for i in range(1, n):
        yield from _one(seen, word, "split", word[:i] + " " + word[i:])


def _one(seen, word, kind, typed):
    if typed != word and typed not in seen:
        seen.add(typed)
        yield kind, typed


def corpus(words, known: set) -> list:
    """One row per slip of each word, skipping slips that are words."""
    rows = []
    for word in words:
        for kind, typed in slips(word):
            if kind != "split" and typed in known:
                continue
            rows.append({"id": f"slip-{len(rows) + 1:06d}", "kind": kind,
                         "intended": word, "typed": typed})
    return rows


def sample(rows, size: int) -> list:
    """`size` rows, the kinds in equal share, the same rows every run."""
    rng = random.Random(SEED)
    by_kind = {kind: [r for r in rows if r["kind"] == kind] for kind in KINDS}
    out = []
    for kind in KINDS:
        take = min(len(by_kind[kind]), size // len(KINDS))
        out.extend(rng.sample(by_kind[kind], take))
    return sorted(out, key=lambda r: r["id"])


def common_words(top: int) -> list:
    """The `top` most common lowercase words of three letters or more."""
    return [lower for lower, cased, _ in wordlist.records()
            if lower.isalpha() and lower.isascii() and cased.islower() and len(lower) >= 3][:top]


def write_tsv(path: Path, header, rows):
    with open(path, "w", newline="") as f:
        writer = csv.writer(f, delimiter="\t", quoting=csv.QUOTE_NONE,
                            quotechar=None, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--top", type=int, default=3000)
    ap.add_argument("--sample", type=int, default=150)
    args = ap.parse_args()
    known = {lower for lower, _, _ in wordlist.records()}
    words = common_words(args.top)
    rows = corpus(words, known)
    OUT.mkdir(parents=True, exist_ok=True)
    write_tsv(OUT / "slips.tsv", ["id", "kind", "intended", "typed"],
              [[r["id"], r["kind"], r["intended"], r["typed"]] for r in rows])
    write_tsv(OUT / "adjacency.tsv", ["letter", "neighbours"],
              [[c, "".join(sorted(neighbours(c)))] for c in "abcdefghijklmnopqrstuvwxyz"])
    write_tsv(SAMPLE, ["id", "slice", "typed", "offsets", "note"],
              [[r["id"], "slips", r["typed"], "-", f"{r['kind']}|{r['intended']}"]
               for r in sample(rows, args.sample)])
    by_kind = {k: sum(r["kind"] == k for r in rows) for k in KINDS}
    print(f"slips: {len(rows)} rows from {len(words)} words {by_kind}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
