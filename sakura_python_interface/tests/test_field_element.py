import unittest
from fourq_software import field_element
from fourq_hardware import constants
from mpmath import *

# Set precision of mpmath library
mp.dps = 9000


class TestBaseFieldElement(unittest.TestCase):

    def test_base_field_elem_square_root(self):
        p = field_element.FieldElement(constants.d.real, constants.d.imag)
        p *= -1
        p -= 1
        d_hat = p
        d_hat_root = d_hat.complex_square_root()
        self.assertTrue(d_hat_root ** 2 == d_hat)

    def test_base_field_elem_power(self):
        p = field_element.FieldElement(constants.d.real, constants.d.imag)
        p_pow_4 = p ** 4
        p_pow_4_alt = p * p * p * p
        p_pow_4_alt_2 = p
        p_pow_4_alt_2 **= 4
        self.assertEqual(p_pow_4, p_pow_4_alt)

