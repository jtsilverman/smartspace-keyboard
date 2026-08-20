#!/usr/bin/env python3
"""Author the alphabet sweep: one word, one slot, every letter in it.

Group A of the probes confounded two things. Each distance band substituted a
different letter, so "how far the wrong key sits" moved together with "which
letter was typed", and `hejlo` failing while `healo` passed could not be read.

The sweep holds the word and the slot fixed and sweeps all 25 other letters
through that slot. Every row differs from its siblings by one letter and
nothing else, so the answers are directly comparable, and the distance from the
true key is a number the analysis can plot rather than a band the corpus
chose.

Every row runs inside the lowercase carrier, because a token typed alone gets
autocap and stock then protects it as a name.

Run from the repo root:

    python3 eval/oracle/gen-sweep.py
"""
import csv
import string
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "eval" / "oracle" / "corpus" / "sweep.tsv"
SWIFT = ROOT / "app" / "SmartSpaceUITests" / "OracleSweep.swift"
CARRIER = "i said {} to him"

# Common words, and the slot the sweep replaces. Slots sit off the first and
# last letter, which the position probe already covers separately.
TARGETS = [("water", 2), ("phone", 2), ("night", 2), ("house", 2),
           ("money", 2), ("check", 2)]


def rows():
    out = []
    for word, slot in TARGETS:
        for letter in string.ascii_lowercase:
            if letter == word[slot]:
                continue
            typed = word[:slot] + letter + word[slot + 1:]
            out.append([f"G-{len(out) + 1:03d}", "sweep",
                        CARRIER.format(typed), "-",
                        f"G|{word}|slot {slot}, {word[slot]} typed as {letter}"])
    return out


def swift_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    data = rows()
    with open(OUT, "w", newline="") as f:
        writer = csv.writer(f, delimiter="\t", quoting=csv.QUOTE_NONE,
                            quotechar=None, lineterminator="\n")
        writer.writerow(["id", "slice", "typed", "offsets", "note"])
        writer.writerows(data)
    lines = ["// GENERATED from eval/oracle/corpus/sweep.tsv by",
             "// eval/oracle/gen-sweep.py -- do not hand-edit.",
             "",
             "let oracleSweep: [OracleRow] = ["]
    for rid, slice_name, typed, _offsets, _note in data:
        lines.append(f"    OracleRow(id: {swift_str(rid)}, "
                     f"slice: {swift_str(slice_name)}, "
                     f"typed: {swift_str(typed)}, offsets: []),")
    lines += ["]", ""]
    SWIFT.write_text("\n".join(lines))
    print(f"sweep: {len(data)} rows over {len(TARGETS)} words")


if __name__ == "__main__":
    main()
