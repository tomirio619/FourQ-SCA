import unittest
from online_template_attack import ota
import numpy as np


class TestOnlineTemplateAttack(unittest.TestCase):

    def test_offsets(self):
        trigger_trace = ota._generate_random_trigger_trace()
        # The offsets of both the doubling and the addition operations
        offsets = ota.determine_offsets_static(trigger_trace, threshold=5)
        ota.save_offsets(offsets)
        loaded_offsets = ota.load_offsets()
        for offset, loaded_offset in zip(offsets, loaded_offsets):
            self.assertTrue(np.array_equal(offset, loaded_offset))

    def test_ota(self):
        todo = 1
        # TODO test whether the OTA behaves as expected
