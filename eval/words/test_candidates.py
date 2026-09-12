"""Tests for the dictionary candidates (specs/autocorrect-loop.md, unit 1).

    python3 -m unittest eval/words/test_candidates.py
"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import candidates  # noqa: E402


class AggregateTests(unittest.TestCase):
    def test_ssa_year_files_sum_to_recent_and_all_time_counts(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, "yob1950.txt").write_text("Mary,F,100\nJohn,M,90\n")
            Path(d, "yob2020.txt").write_text("Olivia,F,50\nJohn,M,10\nMary,F,1\n")
            rows = candidates.aggregate_ssa(Path(d))
        self.assertEqual(rows["John"], (10, 100))
        self.assertEqual(rows["Mary"], (1, 101))
        self.assertEqual(rows["Olivia"], (50, 50))


class OrderTests(unittest.TestCase):
    names = {"Kylian": (400, 400), "John": (90000, 500000), "Zzyzx": (3, 3)}
    brands = [("Venmo", 40), ("Google", 211), ("email", 172)]

    def test_brands_come_first_by_sitelinks_then_names_by_recent_births(self):
        rows = candidates.build(self.names, self.brands, known={"john", "email"}, floor=100)
        self.assertEqual([r["word"] for r in rows], ["Google", "Venmo", "Kylian"])
        self.assertEqual(rows[0]["source"], "brand")
        self.assertEqual(rows[2]["source"], "name")

    def test_a_word_the_list_already_knows_is_not_a_candidate(self):
        rows = candidates.build(self.names, self.brands, known={"john", "email", "google", "venmo"}, floor=100)
        self.assertEqual([r["word"] for r in rows], ["Kylian"])

    def test_a_rare_name_stays_below_the_floor(self):
        rows = candidates.build(self.names, [], known=set(), floor=100)
        self.assertNotIn("Zzyzx", [r["word"] for r in rows])


class BatchTests(unittest.TestCase):
    def test_the_next_batch_skips_words_stock_already_answered(self):
        rows = candidates.build({"Kylian": (400, 400), "Kaius": (300, 300)}, [("Venmo", 40)],
                                known=set(), floor=100)
        batch = candidates.next_batch(rows, recorded={"venmo"}, size=5)
        self.assertEqual([r["word"] for r in batch], ["Kylian", "Kaius"])

    def test_a_batch_row_is_an_oracle_row_in_a_lowercase_carrier(self):
        rows = candidates.build({"Kylian": (400, 400)}, [], known=set(), floor=100)
        row = candidates.oracle_rows(rows)[0]
        self.assertEqual(row["slice"], "words")
        self.assertEqual(row["typed"], "i said kylian today")
        self.assertEqual(row["offsets"], "-")
        self.assertEqual(row["note"], "name|Kylian|400")
        self.assertEqual(row["id"], "word-kylian")


class AcceptedTests(unittest.TestCase):
    stock = [
        {"slice": "words", "typed": "i said venmo today", "produced": "I said Venmo today "},
        {"slice": "words", "typed": "i said jaje today", "produced": "I said Jake today "},
        {"slice": "words", "typed": "i said kylian today", "produced": "I said kylian today "},
        {"slice": "names", "typed": "tell jaje i said hi", "produced": "Tell Jake I said hi "},
    ]
    rows = [{"word": "Venmo", "source": "brand", "weight": 40},
            {"word": "Jaje", "source": "name", "weight": 300},
            {"word": "Kylian", "source": "name", "weight": 400}]

    def test_a_word_stock_leaves_as_typed_is_accepted_with_its_own_casing(self):
        got = candidates.accepted(self.rows, self.stock)
        self.assertEqual([(r["word"], r["source"]) for r in got],
                         [("Venmo", "brand"), ("Kylian", "name")])

    def test_a_word_stock_changes_is_dropped(self):
        got = candidates.accepted(self.rows, self.stock)
        self.assertNotIn("Jaje", [r["word"] for r in got])


if __name__ == "__main__":
    unittest.main()
