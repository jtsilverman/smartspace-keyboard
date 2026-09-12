"""Tests for the loop's scorer and keep rule (specs/autocorrect-loop.md).

    python3 -m unittest eval/loop/test_loop.py
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import score  # noqa: E402

TRANSCRIPT = """\
[COMPLETIONS DEV] 45/47 (95%)
  miss slang: 2 C010:fin->[fine,find,finally] C012:tot->[to,too,tomorrow]
[COMPLETIONS TEST] 45/46 (97%)
[PROTECT TEST] left-alone 92/95 (96%)
✘ Test protectionTestReport() recorded an issue at KeyboardEvalV4Tests.swift:43:9: Expectation failed: (ok * 100 / max(rows.count, 1) → 96) >= (floor → 97)
✘ Test protectionTestReport() failed after 1.006 seconds with 1 issue.
[PROTECT DEV] left-alone 101/101 (100%)
TYPO4-BENCH corrected 102/114 (89%)  left-alone 6  miscorrected 6
TYPO-BENCH corrected 294/320 (91%)  left-alone 8  miscorrected 18
  fat-finger: corrected 100/104  miscorrected 3
ORACLE-AGREE context: 69/100 (69%)
ORACLE-AGREE context/dev: 35/50 (70%)
ORACLE-AGREE context/test: 34/50 (68%)
ORACLE-AGREE total/dev: 164/200 (82%)
ORACLE-AGREE total/test: 169/200 (84%)
ORACLE-AGREE total: 333/400 (83%)
ORACLE-MISS ctx-006a "i will be ther soon" -> "I will be the soon" stock "I will be ther soon"
ORACLE-MISS nosp-018 "the storecloses soon" -> "the store closes soon" stock "The store loses soon"
✘ Test run with 431 tests in 47 suites failed after 15.228 seconds with 1 issue.
"""


class ParseTests(unittest.TestCase):
    def test_reads_every_number_the_keep_rule_uses(self):
        s = score.parse(TRANSCRIPT)
        self.assertTrue(s["build_ok"])
        self.assertEqual(s["oracle"]["total/dev"], [164, 200])
        self.assertEqual(s["oracle"]["total/test"], [169, 200])
        self.assertEqual(s["oracle"]["context/dev"], [35, 50])
        self.assertEqual(s["typo"], {"corrected": 294, "n": 320, "miscorrected": 18})
        self.assertEqual(s["typo4"], {"corrected": 102, "n": 114, "miscorrected": 6})
        self.assertEqual(s["protect"], {"dev": [101, 101], "test": [92, 95]})
        self.assertEqual(s["completions"], {"dev": [45, 47], "test": [45, 46]})
        self.assertEqual(s["failed"], ["protectionTestReport"])
        self.assertEqual(s["tests_total"], 431)
        self.assertFalse(s["suite_ok"])

    def test_dev_misses_come_back_whole(self):
        s = score.parse(TRANSCRIPT)
        self.assertEqual(len(s["misses"]), 2)
        self.assertTrue(s["misses"][0].startswith('ctx-006a "i will be ther soon"'))

    def test_a_transcript_with_no_oracle_line_is_a_broken_build(self):
        s = score.parse("error: cannot find 'foo' in scope\n")
        self.assertFalse(s["build_ok"])


if __name__ == "__main__":
    unittest.main()


import copy  # noqa: E402

import run  # noqa: E402

BASE = score.parse(TRANSCRIPT)
ENGINE = "engine/Sources/TypingEngine/CorrectionEngine.swift"


def after(**edits):
    """A copy of BASE with dotted keys overwritten: oracle.total/dev=[170, 200]."""
    s = copy.deepcopy(BASE)
    for key, value in edits.items():
        head, _, tail = key.partition("__")
        if tail:
            s[head][tail.replace("_", "/")] = value
        else:
            s[head] = value
    return s


class AllowlistTests(unittest.TestCase):
    def test_engine_sources_and_tests_are_the_loops_to_edit(self):
        self.assertTrue(run.allowed(ENGINE))
        self.assertTrue(run.allowed("engine/Tests/TypingEngineTests/ContextRerankTests.swift"))

    def test_word_tables_corpora_oracle_and_benches_are_not(self):
        for path in [
            "engine/Sources/TypingEngine/Resources/wordrank.bin",
            "engine/Tests/TypingEngineTests/OracleAnswers.swift",
            "engine/Tests/TypingEngineTests/OracleAgreementTests.swift",
            "engine/Tests/TypingEngineTests/ProtectCorpus.swift",
            "engine/Tests/TypingEngineTests/TypoBenchmarkTests.swift",
            "engine/Tests/TypingEngineTests/KeyboardEvalV4Tests.swift",
            "engine/tools/gen-wordrank.py",
            "EVAL.md",
            "app/Shared/SystemSpellChecker.swift",
        ]:
            self.assertFalse(run.allowed(path), path)


class VerdictTests(unittest.TestCase):
    def test_dev_up_and_test_flat_is_kept(self):
        kept, reason = run.verdict(BASE, after(oracle__total_dev=[170, 200]), [ENGINE])
        self.assertTrue(kept, reason)
        self.assertIn("dev 164->170", reason)

    def test_dev_flat_is_reverted(self):
        kept, reason = run.verdict(BASE, after(), [ENGINE])
        self.assertFalse(kept)
        self.assertIn("dev", reason)

    def test_test_half_down_is_reverted_even_when_dev_rises(self):
        kept, reason = run.verdict(
            BASE, after(oracle__total_dev=[170, 200], oracle__total_test=[168, 200]), [ENGINE])
        self.assertFalse(kept)
        self.assertIn("test", reason)

    def test_a_guard_drop_is_reverted(self):
        worse = after(oracle__total_dev=[170, 200])
        worse["typo"]["miscorrected"] = 19
        kept, reason = run.verdict(BASE, worse, [ENGINE])
        self.assertFalse(kept)
        self.assertIn("miscorrected", reason)

    def test_a_new_failing_test_is_reverted_and_an_old_one_is_not(self):
        s = after(oracle__total_dev=[170, 200])
        self.assertTrue(run.verdict(BASE, s, [ENGINE])[0])
        s["failed"] = ["protectionTestReport", "splitGuard"]
        kept, reason = run.verdict(BASE, s, [ENGINE])
        self.assertFalse(kept)
        self.assertIn("splitGuard", reason)

    def test_a_file_outside_the_allowlist_is_reverted(self):
        kept, reason = run.verdict(
            BASE, after(oracle__total_dev=[170, 200]),
            [ENGINE, "engine/Tests/TypingEngineTests/OracleAnswers.swift"])
        self.assertFalse(kept)
        self.assertIn("OracleAnswers.swift", reason)

    def test_a_broken_build_is_reverted(self):
        kept, reason = run.verdict(BASE, score.parse("error: x\n"), [ENGINE])
        self.assertFalse(kept)
        self.assertIn("build", reason)

    def test_no_change_is_reverted(self):
        kept, reason = run.verdict(BASE, after(oracle__total_dev=[170, 200]), [])
        self.assertFalse(kept)


class WordsLoopVerdictTests(unittest.TestCase):
    """The dictionary loop is coverage-bound: a batch of accepted words is kept
    when nothing drops, even though the 400-row oracle rarely moves."""
    WORDS = ["engine/tools/vendor/accepted-words.tsv",
             "engine/Sources/TypingEngine/Resources/wordrank.bin",
             "engine/Sources/TypingEngine/Resources/wordpairs.bin"]

    def test_a_flat_oracle_is_kept_in_the_words_loop(self):
        kept, reason = run.verdict(BASE, after(), self.WORDS, loop="words")
        self.assertTrue(kept, reason)

    def test_a_dropped_dev_half_is_still_reverted(self):
        kept, reason = run.verdict(BASE, after(oracle__total_dev=[160, 200]), self.WORDS, loop="words")
        self.assertFalse(kept)

    def test_a_guard_drop_is_still_reverted(self):
        worse = after()
        worse["protect"]["test"] = [90, 95]
        kept, reason = run.verdict(BASE, worse, self.WORDS, loop="words")
        self.assertFalse(kept)
        self.assertIn("protect", reason)

    def test_the_words_loop_may_not_touch_the_rules(self):
        kept, reason = run.verdict(BASE, after(), self.WORDS + [ENGINE], loop="words")
        self.assertFalse(kept)
        self.assertIn("CorrectionEngine", reason)


class LoopOutputTests(unittest.TestCase):
    def test_the_results_log_and_a_failed_batch_log_are_never_judged(self):
        self.assertTrue(run.is_loop_output("eval/loop/results.tsv"))
        self.assertTrue(run.is_loop_output("eval/oracle/record-words-2026-09-12.log"))
        self.assertFalse(run.is_loop_output("eval/oracle/stock-2026-09-12.tsv"))
        self.assertFalse(run.is_loop_output("engine/tools/vendor/accepted-words.tsv"))
