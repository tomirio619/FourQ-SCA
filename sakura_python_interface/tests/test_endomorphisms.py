import unittest
from fourq_software.field_element import FieldElement
from fourq_software.point import Point
from fourq_software.endomorphisms import apply_endomorphism_psi, apply_endomorphism_phi

g_x = FieldElement(0x1A3472237C2FB305286592AD7B3833AA, 0x1E1F553F2878AA9C96869FB360AC77F6)
g_y = FieldElement(0x0E3FEE9BA120785AB924A2462BCBB287, 0x6E1C4AF8630E024249A7C344844C8B5C)
# The base point (or generator)
g = Point(g_x, g_y)


class TestEndomorphisms(unittest.TestCase):

    def test_endo_phi(self):
        p = g
        phi_p_x = FieldElement(113403226128935195806219240105801407254, 82920569607482093960974474391869329660)
        phi_p_y = FieldElement(112261343333228879764631602754130296761, 112268030109125232021422649121101547733)

        phi_p = Point(phi_p_x, phi_p_y)

        # Compute endomorphism
        for i in range(1000):
            p = apply_endomorphism_phi(p)
        self.assertTrue(p.x == phi_p.x and p.y == phi_p.y)

    def test_endo_psi(self):
        p = g
        psi_p_x = FieldElement(156430050012298914213917178576816031714, 8402636734442572998423125982507436457)
        psi_p_y = FieldElement(9116220238999310817464811188102660356, 8028275923948865028896054033384095425)

        chi_p = Point(psi_p_x, psi_p_y)

        # Compute endomorphism
        for i in range(1000):
            p = apply_endomorphism_psi(p)
        self.assertTrue(p.x == chi_p.x and p.y == chi_p.y)
