from fourq_hardware import constants
import mpmath
from fourq_software.field_element import FieldElement


class Point(object):

    def __init__(self, field_elem_x, field_elem_y):
        mpmath.mp.dps = 9000
        # Set precision
        self.x = field_elem_x
        self.y = field_elem_y
        self.a = constants.a
        self.d = constants.d
        self.p = constants.p

    def __add__(self, other):
        """
        Point addition
        :param other:
        :return:
        """
        if not isinstance(other, Point):
            raise Exception("Points can only be added to other points.")
        x1, y1 = self.x, self.y
        x2, y2 = other.x, other.y

        num1 = x1 * y2 + y1 * x2
        den1 = 1 + self.d * x1 * x2 * y1 * y2
        num2 = y1 * y2 - self.a * x1 * x2
        den2 = 1 - self.d * x1 * x2 * y1 * y2

        x3 = num1 / den1
        y3 = num2 / den2

        return Point(x3, y3)

    def dbl(self):
        """
        Point doubling
        :return:
        """
        x1, y1 = self.x, self.y

        x3 = (2 * x1 * y1) / (self.a * x1 ** 2 + y1 ** 2)
        y3 = (y1 ** 2 - self.a * x1 ** 2) / (2 - self.a * x1 ** 2 - y1 ** 2)

        return Point(x3, y3)

    def invert(self):
        x1, y1 = self.x, self.y
        new_x1 = -x1
        return Point(new_x1, y1)

    def on_curve(self):
        x, y = self.x, self.y

        # Calculate left and right-hand sides of the curve equation
        lhs = -(x ** 2) + y ** 2
        rhs = 1 + self.d * x ** 2 * y ** 2
        diff = lhs - rhs
        return diff.real == 0 and diff.imag == 0

    def __mul__(self, other):
        if isinstance(other, int):
            if other == -1:
                return self.invert()
            elif other == 0:
                # Return the neutral element
                return Point(FieldElement(0, 0), FieldElement(1, 0))
            elif other == 1:
                return self
            else:
                raise Exception(
                    "Do not fool me, multiplication with scalar unequal to -1, 0, or 1 has to be done with a \
                    scalar multiplication algorithm ")
        else:
            raise Exception("ECC points can only be multiplied with a scalar of type int")

    __rmul__ = __mul__
