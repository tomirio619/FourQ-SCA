import unittest

import numpy as np
from fourq_hardware import constants
from fourq_hardware import fourq_test_vectors
from fourq_software import endomorphisms
from fourq_software import scalar_decomposition
from fourq_software.field_element import FieldElement
from fourq_software.fourq_ref_impl import fourq_scalar_mult
from fourq_software.point import Point


class TestFourQImplementationSoftware(unittest.TestCase):

    def test_fourq_scalar_table(self):
        g_x = FieldElement(0x1A3472237C2FB305286592AD7B3833AA, 0x1E1F553F2878AA9C96869FB360AC77F6)
        g_y = FieldElement(0x0E3FEE9BA120785AB924A2462BCBB287, 0x6E1C4AF8630E024249A7C344844C8B5C)
        # The base point (or generator)
        g = Point(g_x, g_y)

        p_phi = endomorphisms.apply_endomorphism_phi(g)
        p_psi = endomorphisms.apply_endomorphism_psi(g)
        psi_phi_p = endomorphisms.apply_endomorphism_psi(p_phi)

        # Precompute lookup table
        lookup_table = {}
        for u in range(8):
            # u = (u2, u1, u0)_2
            u0, u1, u2 = u & 1, (u >> 1) & 1, (u >> 2) & 1
            t_u = g + u0 * p_phi + u1 * p_psi + u2 * psi_phi_p
            lookup_table[u] = t_u

        todo = 1

    def test_fourq_scalar_mult(self):
        length = len(fourq_test_vectors.b_xcoords)
        nr_of_test_vectors = len(fourq_test_vectors.b_xcoords) // 4
        for i in range(0, length , 4):
            b_xcoord = fourq_test_vectors.b_xcoords[i:i + 4]
            b_ycoord = fourq_test_vectors.b_ycoords[i:i + 4]
            key = fourq_test_vectors.keys[i:i + 4]
            r_xcoord = fourq_test_vectors.r_xcoords[i:i + 4]
            r_ycoord = fourq_test_vectors.r_ycoords[i:i + 4]
            """
            P = (x, y) with x and y being complex numbers: x = x0 + x1*i and y= y0 + y1*i
            with 
            - x0 = x0_0 << 64 | x0_1 
            - x1 = x1_0 << 64 | x1_1
            - y0 = y0_0 << 64 | y0_1 
            - y1 = y1_0 << 64 | y1_1
            """
            # Base point
            x0_0, x0_1, x1_0, x1_1 = [int(xi_j, 16) for xi_j in b_xcoord]
            y0_0, y0_1, y1_0, y1_1 = [int(yi_j, 16) for yi_j in b_ycoord]

            # Result point
            rx0_0, rx0_1, rx1_0, rx1_1 = [int(rxi_j, 16) for rxi_j in r_xcoord]
            ry0_0, ry0_1, ry1_0, ry1_1 = [int(ryi_j, 16) for ryi_j in r_ycoord]

            # Secret scalar
            k1, k2, k3, k4 = [int(k_i, 16) for k_i in key]

            scalar = k4 << 192 | k3 << 128 | k2 << 64 | k1
            p_x = FieldElement(int(x0_1 << 64 | x0_0), int(x1_1 << 64 | x1_0))
            p_y = FieldElement(int(y0_1 << 64 | y0_0), int(y1_1 << 64 | y1_0))

            p = Point(p_x, p_y)

            # Verify decomposition
            # print("iteration {}".format(i))
            multi_scalar = scalar_decomposition.decompose_scalar(scalar)
            multi_scalar = np.asarray(multi_scalar, dtype=np.uint64)
            reconstructed_scalar = scalar_decomposition.inverse_decomposition_using_eigen(multi_scalar)
            self.assertEqual(scalar % constants.N, reconstructed_scalar % constants.N)
            for ai in multi_scalar:
                # a1 prints first, a4 last
                print('x"{}", '.format(hex(ai)[2:]), end='')
            print("")

            scalar_mult_p = fourq_scalar_mult(p, scalar)

            p_rx = FieldElement(int(rx0_1 << 64 | rx0_0), int(rx1_1 << 64 | rx1_0))
            p_ry = FieldElement(int(ry0_1 << 64 | ry0_0), int(ry1_1 << 64 | ry1_0))

            p_r = Point(p_rx, p_ry)

            self.assertEqual(p_r.x, scalar_mult_p.x)
            self.assertEqual(p_r.y, scalar_mult_p.y)
