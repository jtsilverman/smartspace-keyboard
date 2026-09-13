"""Tests for the slip generator (specs/autocorrect-loop.md, unit 3).

    python3 -m unittest eval/slips/test_slips.py
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gen_slips  # noqa: E402


class AdjacencyTests(unittest.TestCase):
    def test_a_touches_its_row_and_diagonal_neighbours_only(self):
        self.assertEqual(gen_slips.neighbours("a"), {"q", "w", "s", "z"})

    def test_h_reaches_the_diagonal_below_and_not_two_keys_along(self):
        self.assertIn("n", gen_slips.neighbours("h"))
        self.assertIn("b", gen_slips.neighbours("h"))
        self.assertNotIn("k", gen_slips.neighbours("h"))

    def test_adjacency_is_symmetric(self):
        for a in "abcdefghijklmnopqrstuvwxyz":
            for b in gen_slips.neighbours(a):
                self.assertIn(a, gen_slips.neighbours(b), f"{a}-{b}")


class SlipTests(unittest.TestCase):
    def kinds(self, word):
        return {(kind, typed) for kind, typed in gen_slips.slips(word)}

    def test_every_kind_of_one_slip_comes_out(self):
        got = self.kinds("the")
        self.assertIn(("neighbor", "rhe"), got)
        self.assertIn(("drop", "te"), got)
        self.assertIn(("double", "thhe"), got)
        self.assertIn(("swap", "teh"), got)
        self.assertIn(("split", "t he"), got)

    def test_a_slip_never_equals_the_word_and_never_repeats(self):
        rows = list(gen_slips.slips("hello"))
        typed = [t for _, t in rows]
        self.assertNotIn("hello", typed)
        self.assertEqual(len(typed), len(set(typed)))

    def test_a_slip_that_is_a_real_word_is_left_out_of_the_corpus(self):
        rows = gen_slips.corpus(["cat", "car"], known={"cat", "car", "at"})
        typed = [r["typed"] for r in rows]
        self.assertNotIn("car", typed)
        self.assertNotIn("at", typed)
        self.assertIn("cst", typed)

    def test_rows_carry_id_kind_intended_and_typed(self):
        row = gen_slips.corpus(["the"], known={"the"})[0]
        self.assertEqual(set(row), {"id", "kind", "intended", "typed"})
        self.assertTrue(row["id"].startswith("slip-"))


class SampleTests(unittest.TestCase):
    def test_the_stock_sample_is_stratified_by_kind_and_deterministic(self):
        rows = gen_slips.corpus(["the", "and", "you", "that", "have"], known=set())
        a = gen_slips.sample(rows, size=10)
        b = gen_slips.sample(rows, size=10)
        self.assertEqual(a, b)
        kinds = {r["kind"] for r in a}
        self.assertEqual(kinds, {"neighbor", "drop", "double", "swap", "split"})


if __name__ == "__main__":
    unittest.main()
