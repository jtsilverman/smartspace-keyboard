"""Tests for the student model's data pipeline and weight export
(specs/autocorrect-loop.md, unit 5).

    ~/.smartspace-ml/bin/python -m unittest engine/tools/model/test_train.py
"""
import struct
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

import train  # noqa: E402

VOCAB = ["the", "to", "you", "and", "more", "than", "then", "see", "later"]


class EncodeTests(unittest.TestCase):
    def test_a_sentence_becomes_start_then_ids_with_unknown_for_words_off_the_list(self):
        ids = train.encode("See you LATER, xylophone!", VOCAB)
        self.assertEqual(ids, [train.START, 7 + 3, 2 + 3, 8 + 3, train.UNK])

    def test_ids_are_the_words_position_in_the_list_after_three_specials(self):
        self.assertEqual((train.PAD, train.START, train.UNK), (0, 1, 2))
        self.assertEqual(train.encode("the", VOCAB), [train.START, 3])


class WindowTests(unittest.TestCase):
    def test_sequences_pad_to_one_length_and_the_target_is_the_next_word(self):
        x, y = train.batch([[1, 5, 6], [1, 7]], length=4)
        self.assertEqual(x.tolist(), [[1, 5, 6, 0], [1, 7, 0, 0]])
        self.assertEqual(y.tolist(), [[5, 6, train.PAD, train.PAD], [7, train.PAD, train.PAD, train.PAD]])


class ExportTests(unittest.TestCase):
    def test_the_weights_file_carries_a_magic_a_version_the_shape_and_float16_arrays(self):
        weights = {"embed": np.arange(12, dtype=np.float32).reshape(4, 3),
                   "bias": np.array([0.5, -0.5, 1.0], dtype=np.float32)}
        with tempfile.TemporaryDirectory() as d:
            path = Path(d, "contextmodel.bin")
            train.export(weights, vocab_size=4, hidden=3, embed=3, path=path)
            data = path.read_bytes()
        self.assertEqual(data[:4], b"SSCM")
        version, vocab_size, embed, hidden = struct.unpack_from("<IIII", data, 4)
        self.assertEqual((version, vocab_size, embed, hidden), (1, 4, 3, 3))
        read = train.read_export(data)
        np.testing.assert_allclose(read["embed"], weights["embed"], atol=1e-2)
        np.testing.assert_allclose(read["bias"], weights["bias"], atol=1e-2)


if __name__ == "__main__":
    unittest.main()
