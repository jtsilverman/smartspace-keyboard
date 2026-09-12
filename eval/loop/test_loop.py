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
