import unittest
from fourq_software import scalar_recoding
import math
import numpy as np
from tests.test_constants import scalar_decomp_test_vectors
from fourq_software import scalar_decomposition
from fourq_hardware import constants

# Increase print size of numpy arrays
desired_width = 320
np.set_printoptions(linewidth=desired_width)


class TestScalarRecoding(unittest.TestCase):

    # @classmethod
    # def setUpClass(cls):
    #
    #
    # @classmethod
    # def tearDownClass(cls):

    def test_recode_subscalar_using_sign_aligner(self):
        length = 5
        sub_scalar = 14
        sign_aligner = 11
        encoded_sign_aligner = scalar_recoding.apply_signed_nonzero_encoding(np.uint64(sign_aligner), length)
        encoded_sub_scalar = scalar_recoding.recode_sub_scalar_using_sign_aligner(encoded_sign_aligner, sub_scalar)
        self.assertTrue(encoded_sub_scalar.any())

    def test_undo_signed_nonzero_encoding(self):
        for i in range(1, 31, 2):
            length = 5
            signed_nonzero_val = scalar_recoding.apply_signed_nonzero_encoding(np.uint64(i), length)
            print(signed_nonzero_val)
            org_value = scalar_recoding.undo_signed_nonzero_encoding(signed_nonzero_val, length)
            org_value_verif = scalar_recoding.undo_signed_nonzero_encoding_fast(signed_nonzero_val)
            self.assertEqual(i, org_value)

    def _generate_random_64bit_scalars(self):
        """
        Generate 4 64 bit scalars with the first one being odd
        :return:
        """
        multi_scalar = np.random.randint(0, np.iinfo(np.uint64).max - 1, size=4, dtype=np.uint64)
        if multi_scalar[0] % 2 != 1:
            multi_scalar[0] |= np.uint64(1)
        return multi_scalar

    def test_recode_example_64bit(self):
        # multi_scalar = self._generate_random_64bit_scalars()
        multi_scalar = np.asarray(
            [11141347229464416257, 14047439610996959232, 4001508484362378240, 1245141304914268672], dtype=np.uint64)
        base_point_order = 2 ** 256
        glv_sac_matrix = scalar_recoding.recode_multi_scalar_general_unoptimized(multi_scalar, base_point_order,
                                                                                 print_debug=False)
        print(glv_sac_matrix)

    def test_recode_example(self):
        base_point_order = 2 ** 16
        multi_scalar = np.asarray([11, 6, 14, 3], dtype=np.uint64)
        glv_sac_matrix = scalar_recoding.recode_multi_scalar_general_unoptimized(multi_scalar, base_point_order,
                                                                                 print_debug=True)
        expected_result = np.asarray(
            [[1, -1, 1, -1, 1],
             [1, -1, 0, -1, 0],
             [1, 0, 0, -1, 0],
             [0, 0, 1, -1, 1]]
        )
        self.assertTrue(np.array_equal(glv_sac_matrix, expected_result))

    def test_recoding_inverse(self):
        expected_digit_columns = np.array(
            [[1, -1, 1],
             [1, -1, 1],
             [0, 0, 1],
             [0, 0, 1]
             ]
        )
        m = 4
        base_point_order = 2 ** 256
        length = int(math.ceil(math.log(base_point_order, 2) / m)) + 1

        scalars_in_matrix_form = scalar_recoding.get_valid_recoded_matrix(expected_digit_columns, length)
        # print(scalars_in_matrix_form)
        scalar_vals = scalar_recoding.matrix_to_scalars(scalars_in_matrix_form)
        scalar_vals = np.asarray(scalar_vals, dtype=np.uint64)

        glv_sac_matrix = scalar_recoding.recode_multi_scalar_general_unoptimized(scalar_vals, base_point_order)
        # Extract the relevant sub-matrix containing the digit column we want to compare
        digit_columns = glv_sac_matrix[:, :expected_digit_columns.shape[1]]
        self.assertTrue(np.array_equal(digit_columns, expected_digit_columns))

        # Test that if we reconstruct the original scalar, decompose it and apply the signed non-zero encoding,
        # the expected digit columns come out

        c1 = 5 * constants.basis2[0] - 3 * constants.basis3[0] + 2 * constants.basis4[0]
        c1_prime = 5 * constants.basis2[0] - 3 * constants.basis3[0] + 3 * constants.basis4[0]
        # Determine what the multi-scalar is given a1

        # Decompose org scalar
        org_scalar = scalar_decomposition.inverse_decomposition_using_eigen(scalar_vals)
        decomp_scalar = scalar_decomposition.decompose_scalar(org_scalar)
        decomp_scalar = np.asarray(decomp_scalar, dtype=np.uint64)

        # # TEST subtract constant vectors c or c_prime
        # b1, b2, b3, b4 = scalar_decomposition.calculate_babai_optimal_basis()
        # c = [5 * b2[i] - 3 * b3[i] + 2 * b4[i] for i in range(4)]
        # c_prime = [c[i] + b4[i] for i in range(4)]
        # # decomp_scalar = [decomp_scalar[i] - c[i] for i in range(4)]
        # # END TEST

        decomp_scalar = np.asarray(decomp_scalar, dtype=np.uint64)
        recoded_matrix = scalar_recoding.recode_multi_scalar_general_unoptimized(decomp_scalar, base_point_order)
        # print(recoded_matrix)
        # Check if the recoded matrix has matching digit columns
        digit_columns = recoded_matrix[:, :expected_digit_columns.shape[1]]
        matching_digit_columns = np.array_equal(digit_columns, expected_digit_columns)

    def test_recode_random(self):
        for i in range(100):
            multi_scalar = self._generate_random_64bit_scalars()
            glv_sac_matrix = scalar_recoding.recode_multi_scalar_general_unoptimized(multi_scalar, 2 ** 256)
            for row in range(glv_sac_matrix.shape[0]):
                sign_aligner_val = scalar_recoding.scalar_array_to_decimal(glv_sac_matrix[row])
                print(sign_aligner_val)
            print(glv_sac_matrix)
            # print(scalar_recoding.scalar_array_to_decimal([]))
            print("\n")

    def test_structure_of_recoded_matrix(self):
        base_point_order = 2 ** 16
        multi_scalar = np.asarray([31, 18, 26, 2], dtype=np.uint64)
        glv_sac_matrix = scalar_recoding.recode_multi_scalar_general_unoptimized(multi_scalar, base_point_order)
        print(glv_sac_matrix)

    def test_scalar_recoding(self):
        for scalar_decomp_test_vector in scalar_decomp_test_vectors:
            scalar = scalar_decomp_test_vector[0]
            expected_decomposed_scalar = np.asarray(scalar_decomp_test_vector[1], dtype=np.uint64)
            recoded_matrix = scalar_recoding.recode_multi_scalar_general_unoptimized(expected_decomposed_scalar,
                                                                                     2 ** 256)
            scalar_vals = np.asarray(scalar_recoding.matrix_to_scalars(recoded_matrix), dtype=np.uint64)
            self.assertTrue(np.array_equal(scalar_vals, expected_decomposed_scalar))
