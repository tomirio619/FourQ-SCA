from fourq_software.endomorphisms import apply_endomorphism_phi, apply_endomorphism_psi
from fourq_software.point import Point
from fourq_software.scalar_decomposition import decompose_scalar
from fourq_software.scalar_recoding import recode_multi_scalar_general_unoptimized, interpret_recoded_matrix
import numpy as np


def fourq_scalar_mult(base_point: Point, scalar):
    assert 0 <= scalar < 2 ** 256
    # Compute endomorphisms
    p_phi = apply_endomorphism_phi(base_point)
    p_psi = apply_endomorphism_psi(base_point)
    psi_phi_p = apply_endomorphism_psi(p_phi)

    # Precompute lookup table
    lookup_table = {}
    for u in range(8):
        # u = (u2, u1, u0)_2
        u0, u1, u2 = u & 1, (u >> 1) & 1, (u >> 2) & 1
        t_u = base_point + u0 * p_phi + u1 * p_psi + u2 * psi_phi_p
        lookup_table[u] = t_u

    # Decompose scalar
    multi_scalar = decompose_scalar(scalar)
    multi_scalar = np.asarray(multi_scalar, dtype=np.uint64)
    # Recode scalar
    base_point_order = 2 ** 256
    recoded_matrix = recode_multi_scalar_general_unoptimized(multi_scalar, base_point_order)
    signs, digit_cols_vals = interpret_recoded_matrix(recoded_matrix)

    # Main loop
    q = signs[64] * lookup_table[digit_cols_vals[64]]
    for i in reversed(range(64)):
        q = q.dbl()
        t_i = signs[i] * lookup_table[digit_cols_vals[i]]
        q = q + t_i
    return q
