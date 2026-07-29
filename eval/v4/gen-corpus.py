#!/usr/bin/env python3
"""Generate compiled Swift corpus files from the frozen eval/v4 TSVs.

Same pattern as eval-v3: TSVs are the frozen source of truth; generated
Swift files carry a do-not-hand-edit header. Run from repo root:

    python3 eval/v4/gen-corpus.py

Inputs (eval/v4/):
    cap.tsv         id sub context expected note        -> engine test target
    symbols.tsv     id sub context typed expected note  -> engine test target
    protect.tsv     id sub context typed note           -> app/SmartSpaceTests
    typos.tsv       category typed intended             -> app/SmartSpaceTests (appends nothing to v3 typo corpus; separate array)
    completions.tsv id sub context prefix acceptable note -> app/SmartSpaceTests
    scenarios.tsv   id title script expected tolerance note -> app/SmartSpaceUITests
    split-map.tsv   id half(dev|test)                   -> half column on every emitted row
"""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V4 = ROOT / "eval" / "v4"


def swift_str(s: str) -> str:
    # \n in TSV context fields is the two-char escape; keep it as a Swift newline.
    s = s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\\\\n", "\\n")
    return '"' + s + '"'


def read_tsv(name: str, cols: int):
    path = V4 / name
    rows = []
    with open(path, newline="") as f:
        reader = csv.reader(f, delimiter="\t", quoting=csv.QUOTE_NONE, quotechar=None)
        for lineno, row in enumerate(reader, 1):
            if not row or (len(row) == 1 and not row[0].strip()):
                continue
            if len(row) != cols:
                sys.exit(f"{name}:{lineno}: expected {cols} cols, got {len(row)}")
            rows.append(row)
    return rows


def load_split():
    split = dict(read_tsv("split-map.tsv", 2))
    bad = {v for v in split.values()} - {"dev", "test"}
    if bad:
        sys.exit(f"split-map.tsv: bad half values {bad}")
    return split


def half(split, row_id, name):
    if row_id not in split:
        sys.exit(f"{name}: id {row_id} missing from split-map.tsv")
    return split[row_id]


def emit(path: Path, source: str, body: str):
    header = (
        f"// GENERATED from eval/v4/{source} by eval/v4/gen-corpus.py -- do not hand-edit.\n"
        "// Blind-authored keyboard-wide eval v4 (specs/keyboard-eval.md). FROZEN.\n\n"
    )
    path.write_text(header + body)
    print(f"wrote {path.relative_to(ROOT)}")


def main():
    split = load_split()

    rows = read_tsv("cap.tsv", 5)
    lines = [
        f"    CapCase(id: {swift_str(r[0])}, sub: {swift_str(r[1])}, context: {swift_str('' if r[2] == 'EMPTY' else r[2])}, "
        f"expectCap: {'true' if r[3] == 'cap' else 'false'}, half: {swift_str(half(split, r[0], 'cap.tsv'))})"
        for r in rows
    ]
    emit(
        ROOT / "engine/Tests/TypingEngineTests/KeyboardEvalCapCorpus.swift",
        "cap.tsv",
        "struct CapCase { let id: String; let sub: String; let context: String; let expectCap: Bool; let half: String }\n\n"
        "let capCorpus: [CapCase] = [\n" + ",\n".join(lines) + ",\n]\n",
    )

    rows = read_tsv("symbols.tsv", 6)
    lines = [
        f"    SymbolCase(id: {swift_str(r[0])}, sub: {swift_str(r[1])}, context: {swift_str('' if r[2] == 'EMPTY' else r[2])}, "
        f"typed: {swift_str(r[3])}, expected: {swift_str(r[4])}, half: {swift_str(half(split, r[0], 'symbols.tsv'))})"
        for r in rows
    ]
    emit(
        ROOT / "engine/Tests/TypingEngineTests/KeyboardEvalSymbolCorpus.swift",
        "symbols.tsv",
        "struct SymbolCase { let id: String; let sub: String; let context: String; let typed: String; let expected: String; let half: String }\n\n"
        "let symbolCorpus: [SymbolCase] = [\n" + ",\n".join(lines) + ",\n]\n",
    )

    rows = read_tsv("protect.tsv", 5)
    lines = [
        f"    ProtectCase(id: {swift_str(r[0])}, sub: {swift_str(r[1])}, context: {swift_str('' if r[2] == 'EMPTY' else r[2])}, "
        f"typed: {swift_str(r[3])}, half: {swift_str(half(split, r[0], 'protect.tsv'))})"
        for r in rows
    ]
    emit(
        ROOT / "app/SmartSpaceTests/ProtectCorpus.swift",
        "protect.tsv",
        "struct ProtectCase { let id: String; let sub: String; let context: String; let typed: String; let half: String }\n\n"
        "let protectCorpus: [ProtectCase] = [\n" + ",\n".join(lines) + ",\n]\n",
    )

    rows = read_tsv("typos.tsv", 3)
    lines = [
        f"    TypoPairV4(category: {swift_str(r[0])}, typo: {swift_str(r[1])}, intended: {swift_str(r[2])})"
        for r in rows
    ]
    emit(
        ROOT / "app/SmartSpaceTests/TypoCorpusV4.swift",
        "typos.tsv",
        "struct TypoPairV4 { let category: String; let typo: String; let intended: String }\n\n"
        "let typoCorpusV4: [TypoPairV4] = [\n" + ",\n".join(lines) + ",\n]\n",
    )

    rows = read_tsv("completions.tsv", 6)
    lines = [
        f"    CompletionCase(id: {swift_str(r[0])}, sub: {swift_str(r[1])}, context: {swift_str('' if r[2] == 'EMPTY' else r[2])}, "
        f"prefix: {swift_str(r[3])}, acceptable: [{', '.join(swift_str(a.strip()) for a in r[4].split(','))}], "
        f"half: {swift_str(half(split, r[0], 'completions.tsv'))})"
        for r in rows
    ]
    emit(
        ROOT / "app/SmartSpaceTests/CompletionCorpus.swift",
        "completions.tsv",
        "struct CompletionCase { let id: String; let sub: String; let context: String; let prefix: String; let acceptable: [String]; let half: String }\n\n"
        "// acceptable == [\"NONE\"] means offering nothing (or only the typed prefix) passes.\n"
        "let completionCorpus: [CompletionCase] = [\n" + ",\n".join(lines) + ",\n]\n",
    )

    rows = read_tsv("scenarios.tsv", 6)
    lines = [
        f"    ScenarioCase(id: {swift_str(r[0])}, title: {swift_str(r[1])}, script: {swift_str(r[2])}, "
        f"expected: {swift_str(r[3])}, tolerance: {swift_str(r[4])}, note: {swift_str(r[5])})"
        for r in rows
    ]
    emit(
        ROOT / "app/SmartSpaceUITests/ScenarioCorpus.swift",
        "scenarios.tsv",
        "struct ScenarioCase { let id: String; let title: String; let script: String; let expected: String; let tolerance: String; let note: String }\n\n"
        "let scenarioCorpus: [ScenarioCase] = [\n" + ",\n".join(lines) + ",\n]\n",
    )


if __name__ == "__main__":
    main()
