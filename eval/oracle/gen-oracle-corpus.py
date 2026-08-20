#!/usr/bin/env python3
"""Compile the recorded stock answers into a Swift corpus the engine can score
itself against.

`eval/oracle/stock-*.tsv` holds what the real stock keyboard produced for every
frozen row. Checks 3 and 4 of `specs/autocorrect-parity.md` are percentages of
rows where we produce what stock produced, so the recording has to reach the
engine's own test suite. Our candidate source is pure Swift now, so this scores
under `swift test` with no simulator.

The drift gate failed on 2026-08-20 (EVAL.md): two rows in thirty moved. These
numbers are agreement with a recording, never a pass or fail against ground
truth.

Run from the repo root:

    python3 eval/oracle/gen-oracle-corpus.py
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ORACLE = ROOT / "eval" / "oracle"
OUT = ROOT / "engine" / "Tests" / "TypingEngineTests" / "OracleAnswers.swift"
# The four realistic slices. The probes and the sweep are experiments on stock,
# not a corpus we hold ourselves to.
SLICES = {"sloppy", "nospace", "context", "names"}


def swift_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    rows = []
    for path in sorted(ORACLE.glob("stock-*.tsv")):
        with open(path, newline="") as f:
            for row in csv.DictReader(f, delimiter="\t"):
                if row["slice"] in SLICES:
                    rows.append(row)
    rows.sort(key=lambda r: r["id"])
    lines = [
        "// GENERATED from eval/oracle/stock-*.tsv by",
        "// eval/oracle/gen-oracle-corpus.py -- do not hand-edit.",
        "//",
        "// What the real stock keyboard produced for each frozen row, recorded",
        "// through XCUITest. Agreement with a recording, never ground truth:",
        "// the drift gate failed on 2026-08-20 with two rows in thirty moving.",
        "",
        "struct OracleAnswer {",
        "    let id: String",
        "    let slice: String",
        "    /// The keystrokes, lowercase letters and spaces only.",
        "    let typed: String",
        "    /// What stock put in the field, trailing space trimmed.",
        "    let stock: String",
        "}",
        "",
        "let oracleAnswers: [OracleAnswer] = [",
    ]
    for row in rows:
        lines.append(
            f"    OracleAnswer(id: {swift_str(row['id'])}, "
            f"slice: {swift_str(row['slice'])}, "
            f"typed: {swift_str(row['typed'])}, "
            f"stock: {swift_str(row['produced'].strip())}),")
    lines += ["]", ""]
    OUT.write_text("\n".join(lines))
    print(f"oracle answers: {len(rows)} rows")


if __name__ == "__main__":
    main()
