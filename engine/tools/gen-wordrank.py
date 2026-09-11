#!/usr/bin/env python3
"""Regenerate wordrank.bin: the engine's word list, which is both its spelling
vocabulary and its frequency order.

The list is the Android Open Source Project's LatinIME English dictionary
(`engine/tools/vendor/en_wordlist.combined.gz`, Apache-2.0, 165,544 words).
Each entry carries its own casing and a 0-255 frequency, so one file answers
both questions the engine asks: "is this a word" and "how common is it".

The list this replaced was Norvig's `count_1w.txt` top 20k, scraped from web
text, which held `teh` at rank 19395 and `definately` at 19107. A vocabulary
that contains `teh` can never correct `teh`.

The output is a binary file the engine maps read-only (`WordRank.swift`), so
the list costs the keyboard extension no heap: held as Swift dictionaries it
measured about 50MB of a 70MB footprint against a 55MB ceiling (2026-09-11).

Layout, little-endian, offsets from the start of the file:

    header   4s magic "SSWR", u32 version, u32 count, u32 maxLen,
             u32 recordsOff, u32 alphaOff, u32 lengthStartsOff,
             u32 lengthListOff, u32 stringsOff, u32 stringsLen
    records  count x 20 bytes: u32 lowerOff, u32 casedOff, u32 rank,
             u32 letterMask, u8 charCount, u8 lowerBytes, u8 casedBytes,
             u8 flags (bit 0: the lowercase form is not ASCII)
    alpha    count x u32 record indices, sorted by the lowercase bytes
    lengthStarts (maxLen + 2) x u32: for each character count, where its
             run starts in lengthList; the last entry is the list's end
    lengthList count x u32 record indices grouped by character count,
             rank order inside a group
    strings  the lowercase and cased bytes of every record, no separators

One record per distinct lowercase form, the first occurrence in frequency
order winning. `rank` is the word's position in the full list, duplicates
included, so the rank cutoffs the engine holds keep their meaning.

Run from the repo root:

    python3 engine/tools/gen-wordrank.py
"""
import gzip
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "engine" / "Sources" / "TypingEngine" / "Resources" / "wordrank.bin"
LEXICON = ROOT / "engine" / "Sources" / "TypingEngine" / "TextingLexicon.swift"
SOURCE = ROOT / "engine" / "tools" / "vendor" / "en_wordlist.combined.gz"

ENTRY = re.compile(r"^ word=([^,]+),f=(\d+)")
MAGIC = b"SSWR"
VERSION = 1
RECORD = struct.Struct("<IIIIBBBB")
HEADER = struct.Struct("<4sIIIIIIIII")


def aosp_words() -> list:
    """(word, frequency) in the list's own casing, most frequent first."""
    entries = []
    with gzip.open(SOURCE, "rt", encoding="utf-8") as handle:
        for line in handle:
            match = ENTRY.match(line)
            if match:
                entries.append((match.group(1), int(match.group(2))))
    if not entries:
        sys.exit(f"{SOURCE} held no word entries")
    # Frequency first, then alphabetical, so the order is total and a
    # regeneration reproduces the file byte for byte.
    entries.sort(key=lambda pair: (-pair[1], pair[0]))
    return entries


def texting_words() -> list:
    return sorted(set(re.findall(r'"([a-z0-9]+)"', LEXICON.read_text())))


def build() -> list:
    """Every word in rank order, duplicates of a lowercase form included."""
    words = [word for word, _ in aosp_words()]
    seen = {w.lower() for w in words}
    # The texting lexicon is modern slang the 2014 list never had. It lands
    # last: these words are never corrected away, and rank only breaks ties.
    return words + [w for w in texting_words() if w not in seen]


def records() -> list:
    """(lower, cased, rank), one per distinct lowercase form, rank order."""
    seen = set()
    out = []
    for position, word in enumerate(build()):
        lower = word.lower()
        if lower in seen:
            continue
        seen.add(lower)
        out.append((lower, word, position + 1))
    return out


def letter_mask(lower: str) -> int:
    mask = 0
    for char in lower:
        if "a" <= char <= "z":
            mask |= 1 << (ord(char) - ord("a"))
    return mask


def main():
    if not SOURCE.exists():
        sys.exit(f"{SOURCE} is missing; see engine/tools/vendor/NOTICE")
    recs = records()
    strings = bytearray()
    record_bytes = bytearray()
    for lower, cased, rank in recs:
        lower_bytes, cased_bytes = lower.encode(), cased.encode()
        lower_off = len(strings)
        strings += lower_bytes
        cased_off = len(strings)
        strings += cased_bytes
        flags = 0 if lower_bytes.isascii() else 1
        record_bytes += RECORD.pack(lower_off, cased_off, rank, letter_mask(lower),
                                    len(lower), len(lower_bytes), len(cased_bytes), flags)
    alpha = sorted(range(len(recs)), key=lambda i: recs[i][0].encode())
    max_len = max(len(lower) for lower, _, _ in recs)
    by_length = [[] for _ in range(max_len + 1)]
    for i, (lower, _, _) in enumerate(recs):
        by_length[len(lower)].append(i)
    length_starts, length_list = [], []
    for run in by_length:
        length_starts.append(len(length_list))
        length_list += run
    length_starts.append(len(length_list))

    records_off = HEADER.size
    alpha_off = records_off + len(record_bytes)
    length_starts_off = alpha_off + 4 * len(alpha)
    length_list_off = length_starts_off + 4 * len(length_starts)
    strings_off = length_list_off + 4 * len(length_list)
    header = HEADER.pack(MAGIC, VERSION, len(recs), max_len, records_off, alpha_off,
                         length_starts_off, length_list_off, strings_off, len(strings))
    TARGET.parent.mkdir(exist_ok=True)
    TARGET.write_bytes(header + bytes(record_bytes)
                       + struct.pack(f"<{len(alpha)}I", *alpha)
                       + struct.pack(f"<{len(length_starts)}I", *length_starts)
                       + struct.pack(f"<{len(length_list)}I", *length_list)
                       + bytes(strings))
    print(f"wordrank.bin: {len(recs)} records from {len(build())} words, "
          f"{TARGET.stat().st_size} bytes")


if __name__ == "__main__":
    main()
