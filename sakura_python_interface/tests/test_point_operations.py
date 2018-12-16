import unittest

from mpmath import *

from fourq_software.field_element import FieldElement
from fourq_software.point import Point

# Set precision of mpmath library
mp.dps = 9000


class TwistedEdwardsComplex(unittest.TestCase):

    def test_point_on_curve(self):
        """
        See https://github.com/cloudflare/fourq_hardware/blob/master/constants.go
        Also see https://github.com/Microsoft/FourQlib/blob/350724441ce8607cb20b851697780266a45e84c2/FourQ_32bit/eccp2.c
        and https://github.com/bifurcation/fourq/tree/master/impl
        :return:
        """
        # We know that this point is a generator, so it must be on the curve
        """
        Visualization of the structure of a point:
        point{
           x : FieldElement{
                x : BaseFieldElement // real part of the complex number,
                y : BaseFieldElement //  
        }
        
        """
        field_element_x = FieldElement(0x1a3472237c2fb305 << 64 | 0x286592ad7b3833aa,
                                       0x1e1f553f2878aa9c << 64 | 0x96869fb360ac77f6)
        field_element_y = FieldElement(0x0e3fee9ba120785a << 64 | 0xb924a2462bcbb287,
                                       0x6e1c4af8630e0242 << 64 | 0x49a7c344844c8b5c)
        point = Point(field_element_x, field_element_y)
        on_curve = point.on_curve()
        self.assertTrue(on_curve)

    def test_point_addition(self):
        b_xcoords = ["f85c61a796a17623", "03380ead2cedd09d", "c6d7f8f8b501fe5f", "61bc5c4179251636"]
        b_ycoords = ["321d66be8d6da159", "0db39ae2d9a96d12", "134696c3a3f25608", "2064d02912d52505"]
        scalar = ["4d9c7722e582ee6d", "b8f48118358a215d", "200bbfa6a8b72032", "5150c5d41fb74053"]
        """
        P = (x, y) with x and y being complex numbers: x = x0 + x1*i and y= y0 + y1*i
        with 
        - x0 = x0_0 << 64 | x0_1 
        - x1 = x1_0 << 64 | x1_1
        - y0 = y0_0 << 64 | y0_1 
        - y1 = y1_0 << 64 | y1_1
        """
        x0_0, x0_1, x1_0, x1_1 = [int(xi_j, 16) for xi_j in b_xcoords]
        y0_0, y0_1, y1_0, y1_1 = [int(yi_j, 16) for yi_j in b_ycoords]

        p_x = FieldElement(int(x0_1 << 64 | x0_0), int(x1_1 << 64 | x1_0))
        p_y = FieldElement(int(y0_1 << 64 | y0_0), int(y1_1 << 64 | y1_0))

        # Test if P is on the curve
        p = Point(p_x, p_y)
        on_curve = p.on_curve()
        self.assertTrue(on_curve)

        # Test if 2P is on the curve
        p_plus_p = p.dbl()
        on_curve = p_plus_p.on_curve()
        self.assertTrue(on_curve)

        # Test if P + O (with O being the neutral element) equals P and is also on the curve
        p_x = FieldElement(0, 0)
        p_y = FieldElement(1, 0)
        neutral_element = Point(p_x, p_y)
        p_plus_o = p.add(neutral_element)
        on_curve = p_plus_o.on_curve()
        self.assertTrue(on_curve)

        # Test if P + O = P
        self.assertTrue(p_plus_o.x == p.x and p_plus_o.y == p.y)



