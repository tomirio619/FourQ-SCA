import mpmath
from fourq_hardware import constants
from fourq_software.point import Point
from fourq_software.field_element import FieldElement


def calc_root_d_hat() -> FieldElement:
    """
    See Proposition 1 of the paper
    :return: The root of d_hat
    """
    # d = -(1 + 1/ d_hat}) -> d_hat = 1/(-d - 1)
    d = FieldElement(constants.d.real, constants.d.imag)
    d = -d - 1
    d_hat = d.mult_inv_complex()
    d_hat_sqr_root = d_hat.complex_square_root()
    return d_hat_sqr_root


def get_constant_c(i, j, k, l) -> FieldElement:
    """
    The notation $c_{i, j, k, l}$ is used to denote the constant $i + j \sqrt{2} + k\sqrt{5} + l\sqrt{2}\sqrt{5}$ in
    $\mathbb{F}_{p^2}$.
    :param i:
    :param j:
    :param k:
    :param l:
    :return: The base field element $i + j \sqrt{2} + k\sqrt{5} + l\sqrt{2}\sqrt{5}$
    """
    sqrt_2 = FieldElement(2 ** 64, 0)
    sqrt_5 = FieldElement(0, 87392807087336976318005368820707244464)
    c = i + j * sqrt_2 + k * sqrt_5 + l * sqrt_2 * sqrt_5
    return c


def tau(point: Point) -> Point:
    """
    Apply the map Tau (see Proposition 1)
    :param point: A poin on the curve
    :return: The resulting point after the map Tau has been applied
    """
    x = point.x
    y = point.y

    d_hat_root = calc_root_d_hat()

    new_x = (2 * x * y) / ((x ** 2 + y ** 2) * d_hat_root)
    new_y = (x ** 2 - y ** 2 + 2) / (y ** 2 - x ** 2)
    return Point(new_x, new_y)


def tau_dual(point: Point) -> Point:
    """
    Apply the inverse map of Tau (see Proposition 1)
    :param point: A point on the curve
    :return: The resulting field element after the inverse map of Tau has been applied
    """
    x = point.x
    y = point.y

    d_hat_root = calc_root_d_hat()

    new_x = (2 * x * y * d_hat_root) / (x ** 2 - y ** 2 + 2)
    new_y = (y ** 2 - x ** 2) / (y ** 2 + x ** 2)
    return Point(new_x, new_y)


def chi(point: Point) -> Point:
    """
    Apply the composition (\delta \psi_W \delta^{-1}) used in the endomorphism psi to the given point
    :param point: A point on the curve
    :return: The resulting point after the composition of psi has been applied
    """
    x = point.x
    y = point.y

    c1 = get_constant_c(-2, 3, -1, 0)
    c2 = get_constant_c(-140, 99, 0, 0)
    c3 = get_constant_c(-76, 57, -36, 24)
    c4 = get_constant_c(-9, -6, 4, 3)

    new_x = (mpmath.mpc(2j) * x ** constants.p * c1)
    new_x /= (y ** constants.p * (((x ** constants.p) ** 2) * c2 + c3))

    new_y = (c4 - (x ** constants.p) ** 2) / (c4 + (x ** constants.p) ** 2)
    return Point(new_x, new_y)


def upsilon(point: Point) -> Point:
    """
    Apply the composition (\delta \psi_W \delta^{-1}) used in the endomorphism phi to the given point
    :param point : A point on the curve
    :return:  The resulting point after the composition of phi has been applied
    """
    x = point.x
    y = point.y

    c1 = get_constant_c(9, -6, 4, -3)
    c2 = get_constant_c(7, 5, 3, 2)
    c3 = get_constant_c(21, 15, 10, 7)
    c4 = get_constant_c(3, 2, 1, 1)
    c5 = get_constant_c(3, 3, 2, 1)

    c6 = get_constant_c(15, 10, 6, 4)
    c7 = get_constant_c(120, 90, 60, 40)
    c8 = get_constant_c(175, 120, 74, 54)
    c9 = get_constant_c(240, 170, 108, 76)
    c10 = get_constant_c(3055, 2160, 1366, 966)

    new_x = (c1 * x * (y ** 2 - c2 * y + c3) * (y ** 2 + c2 * y + c3))
    new_x /= ((y ** 2 + c4 * y + c5) * (y ** 2 - c4 * y + c5))
    new_x **= constants.p

    new_y = (c6 * (5 * y ** 4 + c7 * y ** 2 + c8))
    new_y /= (5 * y * (y ** 4 + c9 * y ** 2 + c10))
    new_y **= constants.p

    return Point(new_x, new_y)


def apply_endomorphism_phi(point: Point) -> Point:
    """
    Apply the endomorphism phi to the given point
    :param point: AA point on the curve
    :return: The resulting point after the endomorphism phi has been applied
    """
    return tau_dual(upsilon(tau(point)))


def apply_endomorphism_psi(point: Point) -> Point:
    """
    Apply the endomorphism psi to the given point
    :param point: A point on the curve
    :return: The resulting point after the endomorphism psi has been applied
    """
    return tau_dual(chi(tau(point)))


if __name__ == "__main__":
    todo = 1
