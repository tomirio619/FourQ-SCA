import gmpy2
from gmpy2 import mpq

from preconditions import preconditions

from fourq_hardware.constants import *


def calculate_babai_optimal_basis():
    """
    Calculate the Babai optimal basis for the zero decomposition lattice L (see Definition 1 of the FourQ paper).
    :return: B = [b1, b2, b3, b4]
    """

    # Note that int(V/r) will give the wrong result, the same applies to math.floor() and round()
    alpha = V // r  # due to V = 0 mod r, which gives alpha = V /r \in Z
    b1 = [16 * (-60 * alpha + 13 * r - 10),
          4 * (-10 * alpha - 3 * r + 12),
          4 * (-15 * alpha + 5 * r - 13),
          -13 * alpha - 6 * r + 3]
    b2 = [32 * (5 * alpha - r),
          -8,
          8,
          2 * alpha + r]
    b3 = [16 * (80 * alpha - 15 * r + 18),
          4 * (18 * alpha - 3 * r - 16),
          4 * (-15 * alpha - 9 * r + 15),
          15 * alpha + 8 * r + 3]
    b4 = [16 * (-360 * alpha + 77 * r + 42),
          4 * (42 * alpha + 17 * r + 72),
          4 * (85 * alpha - 21 * r - 77),
          (-77 * alpha - 36 * r - 17)]

    b1 = list(map(lambda x: mpq(x, 224), b1))
    b2 = list(map(lambda x: mpq(x, 8), b2))
    b3 = list(map(lambda x: mpq(x, 224), b3))
    b4 = list(map(lambda x: mpq(x, 448), b4))

    result = [b1, b2, b3, b4]

    # Compare with expected results (taken from curve4Q on Github)
    expected_results = [basis1, basis2, basis3, basis4]
    for bi, exp_bi in zip(result, expected_results):
        for bij, exp_bij in zip(bi, exp_bi):
            assert int(bij) == exp_bij
    return result


def calculate_eigenvalue_psi():
    lambda_psi = 4 * (p + 1) * gmpy2.invert(r, N) % N
    return int(lambda_psi)


def calculate_eigenvalue_phi():
    lambda_phi = 4 * (p - 1) * r ** 3 * gmpy2.invert((p + 1) ** 2 * V, N) % N
    return int(lambda_phi)


def calculate_curve_constants():
    """
    Calculate the curve constants $\ell_i$
    :return:
    """
    expected_values = [50127518246259276682880317011538934615153226543083896339791,
                       22358026531042503310338016640572204942053343837521088510715,
                       5105580562119000402467322500999592531749084507000101675068,
                       19494034873545274265741574254707851381713530791194721254848
                       ]
    ells = []
    alpha_hats = calculate_alpha_hats()
    gmpy2.context().real_round = gmpy2.RoundToNearest
    for i in range(4):
        alpha_hat_i = alpha_hats[i]
        ell_i = round(mpq(alpha_hat_i * mu, N))
        # Verify results what precomputed values
        assert ell_i == expected_values[i]
        ells.append(ell_i)
    return ells


def calculate_alpha_tildes(scalar):
    """
    alpha_tilde = floor(ell_i * m / mu)
    :param scalar:
    :return:
    """
    curve_constants = calculate_curve_constants()
    alpha_tildes = []
    for i in range(4):
        curve_constant_ell_i = curve_constants[i]
        alpha_tilde_i = curve_constant_ell_i * scalar // mu
        alpha_tildes.append(alpha_tilde_i)
    return alpha_tildes


def calculate_alpha_hats():
    """
    Calculate the alpha hat values
    :return:
    """
    alpha_hat_1 = 540 * V ** 3 + 10 * r * (27 * r - 4) * V ** 2 + 6 * r ** 2 * (
            9 * r ** 2 - 2 * r + 18) * V + r ** 3 * (27 * r + 4) * (r ** 2 - 2)
    alpha_hat_2 = 1020 * V ** 3 + 10 * r * (47 * r - 8) * V ** 2 + 2 * r ** 2 * (
            51 * r ** 2 + 26 * r + 102) * V + r ** 3 * (47 * r + 8) * (r ** 2 - 2)
    alpha_hat_3 = 220 * V ** 3 + 10 * r * (11 * r + 16) * V ** 2 + 2 * r ** 2 * (
            11 * r ** 2 - 46 * r + 22) * V + r ** 3 * (11 * r - 16) * (r ** 2 - 2)
    alpha_hat_4 = 60 * V ** 3 + 30 * r ** 2 * V ** 2 + 2 * r ** 2 * (3 * r ** 2 + 2 * r + 6) * V + 3 * r ** 4 * (
            r ** 2 - 2)

    alpha_hat_1 = mpq(alpha_hat_1, 6272 * r ** 3)
    alpha_hat_2 = mpq(alpha_hat_2, 25088 * r ** 3)
    alpha_hat_3 = mpq(alpha_hat_3, 25088 * r ** 3)
    alpha_hat_4 = mpq(alpha_hat_4, 1792 * r ** 3)

    result = [alpha_hat_1, alpha_hat_2, alpha_hat_3, alpha_hat_4]
    return result


def inverse_decomposition_using_eigen(multi_scalar):
    a1 = multi_scalar[0]
    a2 = multi_scalar[1]
    a3 = multi_scalar[2]
    a4 = multi_scalar[3]
    lambda_phi = calculate_eigenvalue_phi()
    lambda_psi = calculate_eigenvalue_psi()
    m = a1 + a2 * lambda_phi + a3 * lambda_psi + a4 * lambda_phi * lambda_psi
    m %= N
    return m


@preconditions(
    lambda m: isinstance(m, int),
    lambda m: 0 < m < 2 ** 256
)
def decompose_scalar(m):
    b1, b2, b3, b4 = calculate_babai_optimal_basis()

    c = [5 * b2[i] - 3 * b3[i] + 2 * b4[i] for i in range(4)]
    c_prime = [c[i] + b4[i] for i in range(4)]

    t1, t2, t3, t4 = calculate_alpha_tildes(m)

    a = [m, 0, 0, 0]
    a = [a[i] - t1 * b1[i] - t2 * b2[i] - t3 * b3[i] - t4 * b4[i] for i in range(4)]
    ac = [a[i] + c[i] for i in range(4)]
    acp = [a[i] + c_prime[i] for i in range(4)]

    # Check which one of the multi-scalars has an odd first coordinate (it should be exactly one)
    if int(ac[0]) & 1:
        # The other decomposition should not be odd
        assert not int(acp[0]) & 1
        return ac
    else:
        # The other decomposition should not be odd
        assert not int(ac[0]) & 1
        return acp


if __name__ == "__main__":
    calculate_babai_optimal_basis()
    calculate_alpha_hats()
    calculate_curve_constants()
    calculate_eigenvalue_phi()
