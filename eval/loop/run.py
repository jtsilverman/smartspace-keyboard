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
    "words": ("engine/tools/", "engine/Sources/TypingEngine/Resources/",
              "engine/Sources/TypingEngine/TextingLexicon.swift"),
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
    if dev_a <= dev_b:
        return False, f"dev half did not rise {dev_b}->{dev_a}"
    return True, f"dev {dev_b}->{dev_a}, test {test_b}->{test_a}"
