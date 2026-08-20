#!/usr/bin/env python3
"""Author the probe corpus: controlled experiments on stock's autocorrect.

The four recorded slices are realistic typing, which tells us what stock does
and not why. These probes change one variable per row so the recorded answers
model the rule. Every probe types one token alone, so autocap capitalizes every
row alike and nothing else varies.

    A  distance    one letter swapped for a key 1, 2, or 4 steps away
    B  position    an adjacent slip at the first, middle, or last letter
    C  count       one, two, or three adjacent slips in one word
    D  length      an adjacent slip in a 3, 5, or 8 letter word
    E  shape       adjacent swap, transposition, deletion, doubled letter
    F  context     the same slipped token alone and inside a sentence

Run from the repo root:

    python3 eval/oracle/gen-probes.py
"""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "eval" / "oracle" / "corpus" / "probes.tsv"
SWIFT = ROOT / "app" / "SmartSpaceUITests" / "OracleProbes.swift"

# The stock letter grid. Row 1 sits half a cell right of row 0, and row 2 sits
# a cell and a half right of it (StockLayoutMetrics at 402pt).
ROWS = [("qwertyuiop", 0.0), ("asdfghjkl", 0.5), ("zxcvbnm", 1.5)]
PLACE = {ch: (x0 + i, float(r)) for r, (row, x0) in enumerate(ROWS)
         for i, ch in enumerate(row)}


def steps(a: str, b: str) -> float:
    """Distance between two keys, in cells, with each axis on its own pitch."""
    (ax, ay), (bx, by) = PLACE[a], PLACE[b]
    return ((ax - bx) ** 2 + (ay - by) ** 2) ** 0.5


def keys_at(letter: str, low: float, high: float) -> list:
    return sorted(k for k in PLACE
                  if k != letter and low <= steps(letter, k) <= high)


def pick(letter: str, low: float, high: float, seed: int) -> str:
    """A deterministic key in the band, chosen by position so no clock or RNG
    enters a frozen corpus."""
    band = keys_at(letter, low, high)
    if not band:
        return ""
    return band[seed % len(band)]


# Bands, in cells. 1.45 is the adjacency bound the engine uses.
NEAR = (0.0, 1.45)
MID = (1.9, 2.2)
FAR = (4.0, 99.0)

WORDS_A = ["hello", "water", "table", "money", "phone", "house", "night",
           "movie", "music", "green", "field", "party", "sorry", "happy",
           "check", "start", "dinner", "flight", "coffee", "morning"]
WORDS_B = ["hello", "water", "money", "phone", "house", "night", "party",
           "check", "coffee", "morning"]
WORDS_C = ["hello", "water", "money", "phone", "house", "night", "party",
           "check", "coffee", "morning"]
WORDS_D3 = ["cat", "dog", "run", "bus"]
WORDS_D5 = ["plane", "chair", "bread", "smile"]
WORDS_D8 = ["birthday", "hospital", "computer", "sandwich"]
WORDS_E = ["hello", "water", "money", "phone", "house", "night", "party",
           "check", "coffee", "morning"]
WORDS_F = ["water", "phone", "night", "check", "coffee"]
CARRIERS = {
    "water": "can i have some {} please",
    "phone": "i left my {} at home",
    "night": "see you tomorrow {} then",
    "check": "let me {} the time",
    "coffee": "i need more {} now",
}


def swap(word: str, index: int, letter: str) -> str:
    return word[:index] + letter + word[index + 1:]


def rows():
    out = []

    def add(group, word, typed, note):
        if typed == word or not typed:
            return
        out.append([f"{group}-{len(out) + 1:03d}", "probes", typed, "-",
                    f"{group}|{word}|{note}"])

    # A: how far the wrong key sits from the right one.
    for seed, word in enumerate(WORDS_A):
        i = len(word) // 2
        for band, name in ((NEAR, "near"), (MID, "mid"), (FAR, "far")):
            add("A", word, swap(word, i, pick(word[i], *band, seed)),
                f"one swap at {i}, {name}")

    # B: where in the word the slip lands.
    for seed, word in enumerate(WORDS_B):
        for i, name in ((0, "first"), (len(word) // 2, "middle"),
                        (len(word) - 1, "last")):
            add("B", word, swap(word, i, pick(word[i], *NEAR, seed)),
                f"near swap at {i}, {name}")

    # C: how many slips one word survives.
    for seed, word in enumerate(WORDS_C):
        typed = word
        for count in (1, 2, 3):
            i = (count - 1) * 2 % len(word)
            typed = swap(typed, i, pick(word[i], *NEAR, seed + count))
            add("C", word, typed, f"{count} near swaps")

    # D: whether word length changes the budget.
    for group, words in (("3", WORDS_D3), ("5", WORDS_D5), ("8", WORDS_D8)):
        for seed, word in enumerate(words):
            i = len(word) // 2
            add("D", word, swap(word, i, pick(word[i], *NEAR, seed)),
                f"near swap at {i}, length {group}")

    # E: which slip shapes stock fixes at all.
    for seed, word in enumerate(WORDS_E):
        i = len(word) // 2
        add("E", word, swap(word, i, pick(word[i], *NEAR, seed)), "near swap")
        if word[i] != word[i + 1]:
            add("E", word, word[:i] + word[i + 1] + word[i] + word[i + 2:],
                "transposition")
        add("E", word, word[:i] + word[i + 1:], "deleted letter")
        add("E", word, word[:i] + word[i] + word[i:], "doubled letter")

    # F: the same slipped token alone and in a sentence.
    for seed, word in enumerate(WORDS_F):
        i = len(word) // 2
        typed = swap(word, i, pick(word[i], *NEAR, seed))
        add("F", word, typed, "near swap, alone")
        add("F", word, CARRIERS[word].format(typed), "near swap, in a sentence")
    return out


# Typing a token alone puts it at the start of the field, where autocap
# capitalizes it and stock then reads it as a name and protects it: "helllo"
# came back "Helllo" and "hosue" came back "Josue". Every probe therefore runs
# a second time inside a lowercase carrier, so the token sits mid-sentence in
# lowercase and the slip shape is the only thing left varying.
CARRIER = "i said {} to him"


def carrier_rows(data):
    out = []
    for rid, _slice, typed, _offsets, note in data:
        out.append([rid.replace("-", "c-", 1), "carrier",
                    CARRIER.format(typed), "-", note])
    return out


def swift_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    data = rows()
    data += carrier_rows(data)
    with open(OUT, "w", newline="") as f:
        writer = csv.writer(f, delimiter="\t", quoting=csv.QUOTE_NONE,
                            quotechar=None, lineterminator="\n")
        writer.writerow(["id", "slice", "typed", "offsets", "note"])
        writer.writerows(data)
    alone = [r for r in data if r[1] == "probes"]
    carried = [r for r in data if r[1] == "carrier"]
    lines = [
        "// GENERATED from eval/oracle/corpus/probes.tsv by",
        "// eval/oracle/gen-probes.py -- do not hand-edit. Controlled probes",
        "// of stock's autocorrect (specs/autocorrect-parity.md unit 0).",
        "",
        "let oracleProbes: [OracleRow] = [",
    ]
    for rid, slice_name, typed, _offsets, _note in alone:
        lines.append(f"    OracleRow(id: {swift_str(rid)}, "
                     f"slice: {swift_str(slice_name)}, "
                     f"typed: {swift_str(typed)}, offsets: []),")
    lines += ["]", "", "let oracleCarrierProbes: [OracleRow] = ["]
    for rid, slice_name, typed, _offsets, _note in carried:
        lines.append(f"    OracleRow(id: {swift_str(rid)}, "
                     f"slice: {swift_str(slice_name)}, "
                     f"typed: {swift_str(typed)}, offsets: []),")
    lines += ["]", ""]
    SWIFT.write_text("\n".join(lines))
    groups = {}
    for row in data:
        groups[row[0][0]] = groups.get(row[0][0], 0) + 1
    print(f"probes: {len(data)} rows " +
          ", ".join(f"{k}={v}" for k, v in sorted(groups.items())))


if __name__ == "__main__":
    main()
