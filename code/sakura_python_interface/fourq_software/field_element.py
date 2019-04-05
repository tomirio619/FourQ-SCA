import mpmath
from fourq_hardware import constants
import gmpy2
import numpy as np

mpmath.mp.dps = 9000


class FieldElement(object):

    def __init__(self, real, imag):
        # A point is a complex number: p = a + bi
        self.real = int(real)
        self.imag = int(imag)
        self.point = mpmath.mpc(real, imag)

    def __add__(self, other):
        if isinstance(other, FieldElement):
            p3 = self.point + other.point
            return FieldElement(p3.real % constants.p, p3.imag % constants.p)
        else:
            p3 = self.point + other
            return FieldElement(p3.real % constants.p, p3.imag % constants.p)

    # Allow different operator order for addition if one of the argument is an integer
    __radd__ = __add__

    def __mul__(self, other):
        if isinstance(other, FieldElement):
            # Multiplying two points
            p3 = self.point * other.point
            return FieldElement(p3.real % constants.p, p3.imag % constants.p)
        else:
            p3 = self.point * other
            return FieldElement(p3.real % constants.p, p3.imag % constants.p)

    # Allow different operator order for multiplication if one of the argument is an integer
    __rmul__ = __mul__

    def __sub__(self, other):
        if isinstance(other, FieldElement):
            p3 = self.point - other.point
            return FieldElement(p3.real % constants.p, p3.imag % constants.p)
        else:
            p3 = self.point - other
            return FieldElement(p3.real % constants.p, p3.imag % constants.p)

    def __rsub__(self, other):
        if isinstance(other, FieldElement):
            p3 = other.point - self.point
            return FieldElement(p3.real % constants.p, p3.imag % constants.p)
        else:
            p3 = other - self.point
            return FieldElement(p3.real % constants.p, p3.imag % constants.p)

    def __mod__(self, other):
        return FieldElement(self.point.real % other, self.point.imag % other)

    def __truediv__(self, other):
        if isinstance(other, FieldElement):
            a = int(self.real)
            b = int(self.imag)
            c = int(other.real)
            d = int(other.imag)

            p3_real = (a * c + b * d) % constants.p
            p3_real *= gmpy2.invert(c ** 2 + d ** 2, constants.p)

            p3_imag = (b * c - a * d) % constants.p
            p3_imag *= gmpy2.invert(c ** 2 + d ** 2, constants.p)

            return FieldElement(p3_real % constants.p, p3_imag % constants.p)

        else:
            number_inv = gmpy2.invert(other, constants.p)
            p3 = self.point * number_inv
            return FieldElement(p3.real % constants.p, p3.imag % constants.p)

    def __pow__(self, power, modulo=constants.p):
        """
        Complex modular exponentiation
        :param base: The base (as a complex number)
        :param exponent: The exponent
        :return: base^exponent, performing the calculations mod p
        """
        if power == constants.p:
            # This is the same as a negation (i.e. conjugate)
            new_imag = -self.imag % constants.p
            return FieldElement(self.real, new_imag)
        if modulo == 1:
            return 0
        result = mpmath.mpc(1, 0)
        base_var = self
        while power > 0:
            # check if exponent is odd
            if power & 1:
                result = (base_var * result) % modulo
            power >>= 1
            base_var = base_var * base_var
            base_var %= modulo
        return result

    def __neg__(self):
        p3 = -self.point
        return FieldElement(p3.real % constants.p, p3.imag % constants.p)

    def __lt__(self, other):
        return self.point < other.point

    def __le__(self, other):
        return self.point <= other.point

    def __eq__(self, other):
        return self.point == other.point

    def __gt__(self, other):
        return self.point > other.point

    def __ge__(self, other):
        return self.point >= other.point

    def __str__(self):
        sign = "-" if self.imag <= 0 else "+"
        return "({} {} {}i)".format(self.real, sign, self.imag)

    def mult_inv_complex(self):
        """
        Calculate the multiplicative inverse of a complex number z = x + y*i.
        See https://en.wikipedia.org/wiki/Complex_number#Reciprocal
        :param z: The complex number z = a + b*i unequal to zero
        :return: multiplicative inverse for z=a+bi ≠0
        """
        assert self.point != 0
        x = int(self.point.real) % constants.p
        y = int(self.point.imag) % constants.p
        denom = (x ** 2 + y ** 2) % constants.p
        z_inv_real = x * gmpy2.invert(denom, constants.p) % constants.p
        z_inv_imag = -(y * gmpy2.invert(denom, constants.p)) % constants.p
        return FieldElement(z_inv_real, z_inv_imag)

    def complex_square_root(self):
        """
        Calculat the square root of a complex number in F_(p^2) using the field operations in F_p
        :param z: A complex number
        :return: sqrt(z) if the square-root exists, None otherwise
        """
        a = int(self.point.real) % constants.p
        b = int(self.point.imag) % constants.p
        assert self.point.imag != 0
        mpmath.mp.dps = 9000

        results_real = []
        results_imag = []

        # Explore solutions to the real part
        modulus_sols = self._find_modular_square_root((a ** 2 + b ** 2) % constants.p)
        for modulus_sol in modulus_sols:
            gamma = (a + modulus_sol) * gmpy2.invert(2, constants.p)
            gamma %= constants.p
            second_root_solutions_real = self._find_modular_square_root(gamma)
            if second_root_solutions_real is None:
                continue
            for second_root_sol_real in second_root_solutions_real:
                results_real.append(second_root_sol_real)

        # Explore solutions to the imaginary part
        for modulus_sol in modulus_sols:
            delta = (-a + modulus_sol) * gmpy2.invert(2, constants.p)
            delta %= constants.p
            second_root_solutions_imag = self._find_modular_square_root(delta)
            if second_root_solutions_imag is None:
                continue
            for second_root_sol_imag in second_root_solutions_imag:
                result_imag = np.sign(b) * second_root_sol_imag
                results_imag.append(result_imag % constants.p)

        verfied_results = []
        # Verify which solutions lead to the correct result
        for sol_real in results_real:
            for sol_imag in results_imag:
                root = mpmath.mpc(sol_real, sol_imag)
                pow_of_two = (mpmath.power(root, 2))
                pow_of_two = mpmath.mpc(pow_of_two.real % constants.p, pow_of_two.imag % constants.p)
                if pow_of_two == self.point:
                    verfied_results.append(root)
        return FieldElement(verfied_results[0].real, verfied_results[0].imag) if len(verfied_results) > 0 else None

    def _find_modular_square_root(self, val):
        """
        Find the modular square root of a value.
        See section 2.3.4 of "Elliptic Curve Cryptography
        Implementation and Performance Testing of Curve Representations" by Olav Wegner Eide
        See also here: http://www.mersennewiki.org/index.php/Modular_Square_Root
        :param val: The value for which to find the modular square root.
        :return: if x^2 = u (mod p) exists, find x
        """
        # Check if the root exists using Euler's Criterion
        exponent = (constants.p - 1) // 2
        exp_val = gmpy2.powmod(val % constants.p, exponent, constants.p)
        if exp_val != 1:
            # The given value is a quadratic non-residue of p
            return None
        exponent = (constants.p + 1) // 4
        sqr_root = gmpy2.powmod(val, exponent, constants.p)
        square_roots = [sqr_root, -sqr_root % constants.p]
        for square_root in square_roots:
            assert square_root ** 2 % constants.p == val
        return square_roots
