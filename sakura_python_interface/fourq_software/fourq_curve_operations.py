import gmpy2
from preconditions import preconditions
from fourq_hardware.constants import *


@preconditions(
    lambda a: isinstance(a, complex),
    lambda b: isinstance(b, complex),
    lambda a: 0 <= a.real < 2 ** 128 and 0 <= a.imag < 2 ** 128,
    lambda b: 0 <= b.real < 2 ** 128 and 0 <= b.imag < 2 ** 128
)
def mult(a, b):
    """
    Let a = (a0, a1), b = (b0, b1) \in $\mathbb(F}_{p^2}$
    a x b = (a0 * b0 - a1 * b1, (a0 + a1) * (b0 + b1) - a0 * b0 - a1 * b1)
    :param a: A complex number
    :param b: A complex number
    :return:  a x b
    """
    c = a * b
    real = c.real % p
    imag = c.imag % p
    return complex(real, imag)


@preconditions(
    lambda a: isinstance(a, complex),
    lambda b: isinstance(b, complex),
    lambda a: 0 <= a.real < 2 ** 128 and 0 <= a.imag < 2 ** 128,
    lambda b: 0 <= b.real < 2 ** 128 and 0 <= b.imag < 2 ** 128
)
def add(a, b):
    """
    Let a = (a0, a1), b = (b0, b1) \in $\mathbb(F}_{p^2}$
    a + b = (a0 + b0, a1 + b1)
    :param a: A complex number
    :param b: A complex number
    :return:  a + b
    """
    c = a + b
    real = c.real % p
    imag = c.imag % p
    return complex(real, imag)


@preconditions(
    lambda a: isinstance(a, complex),
    lambda b: isinstance(b, complex),
    lambda a: 0 <= a.real < 2 ** 128 and 0 <= a.imag < 2 ** 128,
    lambda b: 0 <= b.real < 2 ** 128 and 0 <= b.imag < 2 ** 128
)
def sub(a, b):
    """
    Let a = (a0, a1), b = (b0, b1) \in $\mathbb(F}_{p^2}$
    a + b = (a0 - b0, a1 0 b1)
    :param a: A complex number
    :param b: A complex number
    :return:  a - b
    """
    c = a - b
    real = c.real % p
    imag = c.imag % p
    return complex(real, imag)


@preconditions(
    lambda a: isinstance(a, complex),
    lambda b: isinstance(b, complex),
    lambda a: 0 <= a.real < 2 ** 128 and 0 <= a.imag < 2 ** 128,
    lambda b: 0 <= b.real < 2 ** 128 and 0 <= b.imag < 2 ** 128
)
def square(a):
    """
    Let a = (a0, a1) \in $\mathbb(F}_{p^2}$
    a^2 = ((a0 + a1) * (a0 - a1), 2a0 * a1)
    :param a: A complex number
    :param b: A complex number
    :return:  a^2
    """
    a0, a1 = int(a.real), int(a.imag)
    real = (a0 + a1) * (a0 - a1) % p
    imag = (2 * a0 + a1) % p
    return complex(real, imag)


@preconditions(
    lambda a: isinstance(a, complex),
    lambda a: 0 <= a.real < 2 ** 128 and 0 <= a.imag < 2 ** 128,
)
def inv(a):
    """
    Let a = (a0, a1) \in $\mathbb(F}_{p^2}$
    a^(-1) = (a0 * (a0^2 + a1^2)^(-1), -a1 * (a0^2 + a1^2)^(-1))
    :param a: A complex number
    :param b: A complex number
    :return:  a^(-1) mod p
    """
    a0, a1 = int(a.real), int(a.imag)
    inv = gmpy2.invert((a0 ** 2 + a1 ** 2 % p), p)
    real = a0 * inv % p
    imag = -a1 * inv % p
    return complex(real, imag)

@preconditions(
    lambda point: isinstance(point, complex),
    lambda point: 0 <= point.real < 2 ** 128 and 0 <= point.imag < 2 ** 128,
)
def point_on_curve(point):
    """
    Deterimne if a point P = (x, y) is on the curve -x^2 + y^2 = 1 + dx^2y^2
    :param p: The point
    :return: True if the point is on the curve, false otherwise
    """
    x = point.real # real
    y = point.imag # imag
    left_hand_side = -x ** 2 + y ** 2
    right_hang_side = 1 + d * x ** 2 + y ** 2

if __name__ == "__main__":
    # calculate_babai_optimal_bases()
    t1 = complex(5, 3)
    t2 = complex(5, 3)
    res = mult(t1, t2)
    inv_res = inv(res)
    point = (complex(), (complex()))
