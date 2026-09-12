#!/usr/bin/env python3
"""The loop's judge (specs/autocorrect-loop.md, unit 0).

`verdict` keeps one change only when the oracle's dev half rises, the test half
holds, every guard bench holds, no test turns red that was green before, and
no file outside the loop's allowlist moved. `allowed` is the allowlist. Both
are pure; the loops that call them own the git and the scoring.
"""

# What no loop may touch: a benchmark row never moves beside an engine change,
# the oracle is frozen, and the benches are the judge's own instruments.
FORBIDDEN = (
    "EVAL.md",
    "app/",
    "eval/oracle/",
    "engine/Tests/TypingEngineTests/OracleAnswers.swift",
    "engine/Tests/TypingEngineTests/OracleAgreementTests.swift",
    "engine/Tests/TypingEngineTests/TypoBenchmarkTests.swift",
    "engine/Tests/TypingEngineTests/KeyboardEvalV4Tests.swift",
)
FORBIDDEN_SUFFIXES = ("Corpus.swift", "CorpusV4.swift")

# Where a loop may work. The dictionary loop widens the tables; the model loop
# swaps the context model. Neither edits the rules.
ALLOWED = {
    "rules": ("engine/Sources/TypingEngine/", "engine/Tests/TypingEngineTests/"),
    "words": ("engine/tools/vendor/accepted-words.tsv",
              "engine/Sources/TypingEngine/Resources/"),
    "model": ("engine/Sources/TypingEngine/Resources/",
              "engine/Sources/TypingEngine/ContextModel", "engine/tools/model/",
              "engine/Tests/TypingEngineTests/ContextModelTests.swift"),
}


def allowed(path: str, loop: str = "rules") -> bool:
    if path.startswith(FORBIDDEN) or path.endswith(FORBIDDEN_SUFFIXES):
        return False
    if loop == "rules" and path.startswith("engine/Sources/TypingEngine/Resources/"):
        return False
    return path.startswith(ALLOWED[loop])


def _guards(before: dict, after: dict):
    """Every number that must not get worse, as (name, before, after, worse)."""
    yield ("typo corrected", before["typo"]["corrected"], after["typo"]["corrected"],
           after["typo"]["corrected"] < before["typo"]["corrected"])
    yield ("typo miscorrected", before["typo"]["miscorrected"], after["typo"]["miscorrected"],
           after["typo"]["miscorrected"] > before["typo"]["miscorrected"])
    yield ("typo4 corrected", before["typo4"]["corrected"], after["typo4"]["corrected"],
           after["typo4"]["corrected"] < before["typo4"]["corrected"])
    yield ("typo4 miscorrected", before["typo4"]["miscorrected"], after["typo4"]["miscorrected"],
           after["typo4"]["miscorrected"] > before["typo4"]["miscorrected"])
    for kind in sorted(set(before.get("slips", {})) & set(after.get("slips", {}))):
        b, a = before["slips"][kind], after["slips"][kind]
        yield (f"slips {kind} corrected", b["corrected"], a["corrected"], a["corrected"] < b["corrected"])
        yield (f"slips {kind} miscorrected", b["miscorrected"], a["miscorrected"], a["miscorrected"] > b["miscorrected"])
    for slot in ("protect", "completions"):
        for half in ("dev", "test"):
            b, a = before[slot][half][0], after[slot][half][0]
            yield (f"{slot} {half}", b, a, a < b)


def verdict(before: dict, after: dict, changed: list, loop: str = "rules") -> tuple:
    """(kept, reason). Reads only the scorer's JSON and the changed paths."""
    if not changed:
        return False, "no change"
    for path in changed:
        if not allowed(path, loop):
            return False, f"touched {path}"
    if not after["build_ok"]:
        return False, "build failed"
    new_red = sorted(set(after["failed"]) - set(before["failed"]))
    if new_red:
        return False, "new failing tests: " + " ".join(new_red)
    if after["tests_total"] < before["tests_total"]:
        return False, f"tests removed {before['tests_total']}->{after['tests_total']}"
    for name, b, a, worse in _guards(before, after):
        if worse:
            return False, f"guard dropped: {name} {b}->{a}"
    dev_b, dev_a = before["oracle"]["total/dev"][0], after["oracle"]["total/dev"][0]
    test_b, test_a = before["oracle"]["total/test"][0], after["oracle"]["total/test"][0]
    if test_a < test_b:
        return False, f"test half dropped {test_b}->{test_a}"
    if loop == "words":
        # Coverage-bound: the batch is the gain, the oracle must only hold.
        if dev_a < dev_b:
            return False, f"dev half dropped {dev_b}->{dev_a}"
    elif dev_a <= dev_b:
        return False, f"dev half did not rise {dev_b}->{dev_a}"
    return True, f"dev {dev_b}->{dev_a}, test {test_b}->{test_a}"


# --------------------------------------------------------------------------
# The words loop: ask stock about a batch, take what it accepted, rebuild the
# tables, score, keep or revert, log, repeat.
# --------------------------------------------------------------------------

import argparse
import datetime
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RESULTS = ROOT / "eval" / "loop" / "results.tsv"
WORDS_FILES = ["engine/tools/vendor/accepted-words.tsv",
               "engine/Sources/TypingEngine/Resources/wordrank.bin",
               "engine/Sources/TypingEngine/Resources/wordpairs.bin"]
AUTHOR = "autocorrect-loop <autocorrect-loop@local>"


def sh(*cmd, cwd=ROOT, check=True):
    return subprocess.run(list(cmd), cwd=cwd, capture_output=True, text=True, check=check)


def is_loop_output(path: str) -> bool:
    """The loop's own record, never a judged change: results.tsv, and the
    recorder log a failed batch leaves behind (a kept batch commits its log
    with the recording)."""
    return path == "eval/loop/results.tsv" or (
        path.startswith("eval/oracle/record-words-") and path.endswith(".log"))


def changed_files() -> list:
    out = sh("git", "status", "--short", "--untracked-files=all").stdout
    return sorted(line[3:] for line in out.splitlines()
                  if line.strip() and not is_loop_output(line[3:]))


def log_result(loop: str, batch: int, kept: bool, reason: str, before: dict, after: dict, note: str):
    new = not RESULTS.exists()
    with open(RESULTS, "a") as f:
        if new:
            f.write("when\tloop\tbatch\tverdict\treason\tdev\ttest\ttypo_mis\tprotect_test\tnote\n")
        f.write("\t".join([
            datetime.datetime.now().isoformat(timespec="seconds"), loop, str(batch),
            "kept" if kept else "reverted", reason,
            f"{before['oracle']['total/dev'][0]}->{after['oracle']['total/dev'][0]}",
            f"{before['oracle']['total/test'][0]}->{after['oracle']['total/test'][0]}",
            f"{before['typo']['miscorrected']}->{after['typo']['miscorrected']}",
            f"{before['protect']['test'][0]}->{after['protect']['test'][0]}",
            note.replace("\t", " ").replace("\n", " "),
        ]) + "\n")


def words_loop(udid: str, batches: int, size: int) -> int:
    sys.path.insert(0, str(ROOT / "eval" / "loop"))
    import score
    if changed_files():
        sys.exit("the working tree is not clean; the loop commits and reverts in it")
    # The Xcode project is generated and never tracked, so a fresh worktree
    # has none and the recorder's xcodebuild call fails on it (2026-09-12).
    if not (ROOT / "app" / "SmartSpace.xcodeproj").exists():
        sh("xcodegen", "generate", cwd=ROOT / "app")
    best = score.score(ROOT)
    for batch in range(1, batches + 1):
        before = best
        record = subprocess.run(
            [sys.executable, str(ROOT / "eval/oracle/record.py"), udid, "words", "--size", str(size)],
            cwd=ROOT, capture_output=True, text=True)
        print(record.stdout.strip().splitlines()[-1] if record.stdout.strip() else record.stderr[-300:])
        if record.returncode != 0:
            log_result("words", batch, False, "recorder failed", before, before, record.stderr[-200:])
            return 1
        accepted = sh(sys.executable, str(ROOT / "eval/words/candidates.py"), "--accepted").stderr.strip()
        sh(sys.executable, str(ROOT / "engine/tools/gen-wordrank.py"))
        sh(sys.executable, str(ROOT / "engine/tools/gen-wordpairs.py"))
        # The recording and its log are evidence, never a judged change.
        status = sh("git", "status", "--short", "--untracked-files=all").stdout
        recordings = [line[3:] for line in status.splitlines()
                      if line[3:].startswith("eval/oracle/")]
        for path in recordings:
            sh("git", "add", path)
        sh("git", "commit", "-q", "--author", AUTHOR, "-m",
           f"Loop: stock answered a batch of {size} candidate words\n\n{accepted}")
        after = score.score(ROOT)
        changed = changed_files()
        kept, reason = verdict(best, after, changed, loop="words")
        if kept:
            for path in changed:
                sh("git", "add", path)
            sh("git", "commit", "-q", "--author", AUTHOR, "-m",
               f"Loop: the words stock accepted enter the list\n\n{accepted}\n"
               f"oracle dev {best['oracle']['total/dev'][0]}->{after['oracle']['total/dev'][0]}, "
               f"test {best['oracle']['total/test'][0]}->{after['oracle']['total/test'][0]}; "
               f"typo miscorrected {best['typo']['miscorrected']}->{after['typo']['miscorrected']}; "
               f"protection test {best['protect']['test'][0]}->{after['protect']['test'][0]}")
            best = after
        else:
            for path in changed:
                sh("git", "checkout", "--", path)
        log_result("words", batch, kept, reason, before, after, accepted)
        print(f"batch {batch}: {'kept' if kept else 'reverted'} ({reason}) {accepted}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="the dictionary loop (specs/autocorrect-loop.md)")
    ap.add_argument("--loop", choices=["words"], required=True)
    ap.add_argument("--udid", required=True)
    ap.add_argument("--batches", type=int, default=1)
    ap.add_argument("--size", type=int, default=150)
    args = ap.parse_args()
    return words_loop(args.udid, args.batches, args.size)


if __name__ == "__main__":
    sys.exit(main())
