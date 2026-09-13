"""Tests for the teacher text generator (specs/autocorrect-loop.md, unit 4).

    python3 -m unittest eval/corpus/test_teach.py
"""
import random
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import teach  # noqa: E402


class PromptTests(unittest.TestCase):
    def test_a_prompt_seeds_a_topic_a_register_and_three_list_words(self):
        rng = random.Random(1)
        prompt = teach.prompt(rng, words=["coffee", "train", "sorry", "later", "dog"])
        self.assertIn("text messages", prompt)
        used = [w for w in ["coffee", "train", "sorry", "later", "dog"] if w in prompt]
        self.assertEqual(len(used), 3)

    def test_the_same_seed_gives_the_same_prompt(self):
        words = ["coffee", "train", "sorry", "later", "dog"]
        self.assertEqual(teach.prompt(random.Random(7), words), teach.prompt(random.Random(7), words))


class CleanTests(unittest.TestCase):
    def test_numbering_quotes_and_blank_lines_go_and_one_message_per_line_stays(self):
        raw = '1. "Hey, running late"\n\n- On my way!\n"Sure thing" \n3) ok see you\n'
        self.assertEqual(teach.clean(raw), ["Hey, running late", "On my way!", "Sure thing", "ok see you"])

    def test_a_line_with_a_url_or_a_non_ascii_character_goes(self):
        raw = "See http://x.co now\nSounds good \U0001F600\nSee you at 5\n"
        self.assertEqual(teach.clean(raw), ["See you at 5"])

    def test_a_line_that_is_not_mostly_in_the_vocabulary_goes(self):
        vocab = {"see", "you", "at", "the", "gym"}
        lines = ["see you at the gym", "see you at the xylophonium quantumly"]
        self.assertEqual(teach.in_vocab(lines, vocab, ratio=0.9), ["see you at the gym"])


class DedupeTests(unittest.TestCase):
    def test_a_repeated_message_is_kept_once_regardless_of_case_and_punctuation(self):
        seen = set()
        out = teach.dedupe(["On my way!", "on my way", "Be there soon", "on my way."], seen)
        self.assertEqual(out, ["On my way!", "Be there soon"])
        self.assertEqual(len(seen), 2)


if __name__ == "__main__":
    unittest.main()
