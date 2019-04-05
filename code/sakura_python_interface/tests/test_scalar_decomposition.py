import gmpy2
import unittest
from gmpy2 import mpq

from fourq_hardware import constants
from fourq_software import scalar_decomposition
from fourq_software.scalar_decomposition import inverse_decomposition_using_eigen
from tests.test_constants import scalar_decomp_test_vectors


class TestsScalarDecomposition(unittest.TestCase):

    def test_roundings(self):
        gmpy2.get_context().real_round = gmpy2.RoundToNearest
        for test_vector in scalar_decomp_test_vectors:
            scalar = test_vector[0]
            # alpha_tilde = floor(ell_i * m / mu) ~ round((alpha_hat_i / N) * scalar)
            alpha_tildes = scalar_decomposition.calculate_alpha_tildes(scalar)
            alpha_hats = scalar_decomposition.calculate_alpha_hats()
            # the values of alpha_tilde should be equal to round((alpha_hat / N) * m)
            for alpha_tilde, alpha_hat in zip(alpha_tildes, alpha_hats):
                alpha_rounded = round(mpq(alpha_hat * scalar, constants.N))
                # computing the rounding in this way means the answer can be out by 1 in some cases
                diff = alpha_rounded - alpha_tilde
                self.assertTrue(0 <= diff <= 1)

    def test_decomposition(self):
        for test_vector in scalar_decomp_test_vectors:
            scalar = test_vector[0]
            expected_decomposed_scalar = test_vector[1]
            decomposed_scalar = scalar_decomposition.decompose_scalar(scalar)

            # Verify decomposition
            self.assertEqual(decomposed_scalar, expected_decomposed_scalar)

            # Test if the scalar represented by the decomposition matches the original scalar
            at1, at2, at3, at4 = scalar_decomposition.calculate_alpha_tildes(scalar)
            b1, b2, b3, b4 = scalar_decomposition.calculate_babai_optimal_basis()

            alp1_times_b1 = [b1[i] * at1 for i in range(4)]
            alp2_times_b2 = [b2[i] * at2 for i in range(4)]
            alp3_times_b3 = [b3[i] * at3 for i in range(4)]
            alp4_times_b4 = [b4[i] * at4 for i in range(4)]

            alpi_times_bi_all = [alp1_times_b1, alp2_times_b2, alp3_times_b3, alp4_times_b4]

            # (a1, a2, a3, a4) = (m, 0, 0, 0) - sum_{i = 1}^{4} round(alpha_tilde_i) * b_i
            # Thus we can calculate m
            reconstructed_scalar = decomposed_scalar
            for j in range(4):
                alpi_times_bi = alpi_times_bi_all[j]
                reconstructed_scalar = [reconstructed_scalar[i] + alpi_times_bi[i] for i in range(4)]

            # Subtract constants
            c = [5 * b2[i] - 3 * b3[i] + 2 * b4[i] for i in range(4)]
            c_prime = [c[i] + b4[i] for i in range(4)]

            reconstructed_scalar_1 = [reconstructed_scalar[i] - c[i] for i in range(4)]
            reconstructed_scalar_2 = [reconstructed_scalar[i] - c_prime[i] for i in range(4)]

            # Check which one equals (m, 0, 0, 0)
            if reconstructed_scalar_1[1:] == [0, 0, 0]:
                reconstructed_scalar = reconstructed_scalar_1
            else:
                reconstructed_scalar = reconstructed_scalar_2
            self.assertEqual(reconstructed_scalar[0] % constants.N, scalar % constants.N)

    def test_inverse_decomposition_using_eigen(self):
        for test_vector in scalar_decomp_test_vectors:
            expected_scalar = test_vector[0]
            decomposed_scalar = test_vector[1]
            # Expected result after 'undoing' the scalar decomposition

            # Retrieve the multi scalar
            a1, a2, a3, a4 = decomposed_scalar

            # Calculate the eigenvalues of the endomorphisms phi and psi
            lambda_phi = scalar_decomposition.calculate_eigenvalue_phi()
            lambda_psi = scalar_decomposition.calculate_eigenvalue_psi()

            # Calculate m = a1 + a2 * λ_phi + a3*λ_psi + a4 * λ_phi * λ_psi (mod N) with 0 <= a_i < 2^(64) - 1
            scalar = (a1 + a2 * lambda_phi + a3 * lambda_psi + a4 * lambda_phi * lambda_psi) % constants.N
            self.assertEqual(scalar % constants.N, expected_scalar % constants.N)

    def test_inverse_decomposition_using_sum(self):
        for test_vector in scalar_decomp_test_vectors[1:]:
            scalar = test_vector[0]
            decomposed_scalar = test_vector[1]

            # Test if the scalar represented by the decomposition matches the original scalar
            at1, at2, at3, at4 = scalar_decomposition.calculate_alpha_tildes(scalar)
            b1, b2, b3, b4 = scalar_decomposition.calculate_babai_optimal_basis()

            alp1_times_b1 = [b1[i] * at1 for i in range(4)]
            alp2_times_b2 = [b2[i] * at2 for i in range(4)]
            alp3_times_b3 = [b3[i] * at3 for i in range(4)]
            alp4_times_b4 = [b4[i] * at4 for i in range(4)]

            alpi_times_bi_all = [alp1_times_b1, alp2_times_b2, alp3_times_b3, alp4_times_b4]

            # (a1, a2, a3, a4) = (m, 0, 0, 0) - sum_{i = 1}^{4} round(alpha_tilde_i) * b_i
            # Thus we can calculate m
            reconstructed_scalar = decomposed_scalar
            for j in range(4):
                alpi_times_bi = alpi_times_bi_all[j]
                reconstructed_scalar = [reconstructed_scalar[i] + alpi_times_bi[i] for i in range(4)]

            # Subtract constants
            c = [5 * b2[i] - 3 * b3[i] + 2 * b4[i] for i in range(4)]
            c_prime = [c[i] + b4[i] for i in range(4)]

            reconstructed_scalar_1 = [reconstructed_scalar[i] - c[i] for i in range(4)]
            reconstructed_scalar_2 = [reconstructed_scalar[i] - c_prime[i] for i in range(4)]

            # Check which one equals (m, 0, 0, 0)
            if reconstructed_scalar_1[1:] == [0, 0, 0]:
                reconstructed_scalar = reconstructed_scalar_1
            else:
                reconstructed_scalar = reconstructed_scalar_2
            self.assertEqual(reconstructed_scalar[0] % constants.N, scalar % constants.N)

    def test_get_org_scalar_from_decomposition(self):
        for test_vector in scalar_decomp_test_vectors[1:]:
            expected_scalar = test_vector[0]
            decomposed_scalar = test_vector[1]
            reconstructed_scalar = inverse_decomposition_using_eigen(decomposed_scalar)
            self.assertEqual(reconstructed_scalar, expected_scalar % constants.N)
