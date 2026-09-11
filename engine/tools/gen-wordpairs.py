#!/usr/bin/env python3
"""Regenerate wordpairs.bin: the engine's word-pair table, which is how a
correction reads the word before it (unit 4a of specs/autocorrect-parity.md).

The counts are Norvig's `count_2w.txt` (`engine/tools/vendor/count_2w.txt.gz`,
the quarter-million most frequent bigrams of the Google Web Trillion Word
Corpus). A pair is kept when both words are in the word list, because a word
the engine cannot propose never needs a pair, and when its count reaches the
floor.

The floor is 300,000. The weakest split stock made in the recorded
missed-space slice that the counts hold at all is "breakfast is" at 346,954,
and "bad ass" sits at 204,647: a floor between them keeps "badass", a
protection row the 2014 word list does not know, from splitting.

The output is a binary file the engine maps read-only (`WordPairs.swift`).
Layout, little-endian: 4s magic "SSWP", u32 version, u32 count, u32 zero,
then count x 12 bytes of u32 first, u32 second, u32 count, sorted by
(first, second), where first and second are record indices in wordrank.bin.

Run from the repo root, after gen-wordrank.py:

    python3 engine/tools/gen-wordpairs.py
"""
import gzip
import importlib.util
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "engine" / "Sources" / "TypingEngine" / "Resources" / "wordpairs.bin"
SOURCE = ROOT / "engine" / "tools" / "vendor" / "count_2w.txt.gz"
FLOOR = 300_000
MAGIC = b"SSWP"
VERSION = 1


def record_index() -> dict:
    """Lowercase word -> record index in wordrank.bin."""
    spec = importlib.util.spec_from_file_location(
        "gen_wordrank", Path(__file__).with_name("gen-wordrank.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return {lower: i for i, (lower, _, _) in enumerate(module.records())}


def pairs(index: dict) -> list:
    kept = []
    with gzip.open(SOURCE, "rt", encoding="utf-8") as handle:
        for line in handle:
            bigram, count = line.rstrip("\n").split("\t")
            count = int(count)
            if count < FLOOR:
                continue
            first, second = bigram.split(" ")
            if first.isalpha() and second.isalpha() \
                    and first in index and second in index:
                kept.append((index[first], index[second], count))
    if not kept:
        sys.exit(f"{SOURCE} held no pairs")
    kept.sort()
    return kept


def main():
    if not SOURCE.exists():
        sys.exit(f"{SOURCE} is missing; see engine/tools/vendor/NOTICE")
    rows = pairs(record_index())
    body = b"".join(struct.pack("<III", *row) for row in rows)
    TARGET.write_bytes(struct.pack("<4sIII", MAGIC, VERSION, len(rows), 0) + body)
    print(f"wordpairs.bin: {len(rows)} pairs at or above {FLOOR:,}, "
          f"{TARGET.stat().st_size} bytes")


if __name__ == "__main__":
    main()
