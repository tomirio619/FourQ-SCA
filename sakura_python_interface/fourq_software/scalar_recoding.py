import math

import numpy as np
from preconditions import preconditions


@preconditions(
    lambda encoded_sign_aligner: isinstance(encoded_sign_aligner, np.ndarray),
)
def undo_signed_nonzero_encoding(encoded_sign_aligner, length):
    """
    Undo the signed nonzero encoding that is applied to the sign aligner scalar (which is a odd positive number)
    :param encoded_sign_aligner: The sign aligner as an array of
    :return: The original scalar that corresponds to the recoded multi-scalar in signed non-zero form
    """
    k_J = []
    for i in range(1, length):
        # Determine value of current bit by add one to this value and divide by 2
        bit_val = int((encoded_sign_aligner[i] + 1) / 2)
        k_J = np.append(k_J, bit_val)
    # We know the scalar that was converted in the sign aligner is odd. Therefore, k_0^J = 1
    k_J = np.append(k_J, 1)
    """
    Convert array representing a binary number to an int using numpy's dot-product with a 2-powered range array
    See here: https://stackoverflow.com/questions/41069825/convert-binary-01-numpy-to-integer-or-binary-string
    """
    test = ''.join(map(str, k_J.astype(int)))
    k_J = k_J.dot(2 ** np.arange(k_J.size)[::-1])
    return k_J


@preconditions(
    lambda encoded_sign_aligner: isinstance(encoded_sign_aligner, np.ndarray),
)
def undo_signed_nonzero_encoding_fast(encoded_sign_aligner):
    result = encoded_sign_aligner.dot(2 ** np.arange(encoded_sign_aligner.size)[::-1])
    return result


@preconditions(
    lambda encoded_sign_aligner: isinstance(encoded_sign_aligner, np.ndarray),
)
def recode_sub_scalar_using_sign_aligner(encoded_sign_aligner, scalar):
    length = len(encoded_sign_aligner)
    encoded_sub_scalar = np.zeros(length)
    scalar_mut = np.uint64(scalar)
    for i in range(length):
        sign_aligner_val_i = np.int8(encoded_sign_aligner[length - i - 1])
        key_j_bit_0 = scalar_mut & np.uint64(1)
        val_j_i = np.int8(sign_aligner_val_i * key_j_bit_0)
        # b_i^j = b_i^J * k_0^J
        encoded_sub_scalar[length - i - 1] = val_j_i
        # k_j = floor(k_j / 2) - floor(b_i^j / 2)
        val_j_i = math.floor(val_j_i / 2)
        scalar_mut = np.floor_divide(scalar_mut, np.uint64(2))
        scalar_mut -= np.int64(val_j_i)
        scalar_mut = np.uint64(scalar_mut)
    return encoded_sub_scalar


@preconditions(
    lambda sign_aligner: isinstance(sign_aligner, np.uint64)
)
def apply_signed_nonzero_encoding(sign_aligner, length):
    """
    replacing every sequence 00 .. 01 in the sign aligner by 1(-1)...(-1)(-1) (keeping the same number of digits)
    """
    encoded_sign_aligner = np.array([1])

    for ctr in range(length - 1):
        bit_value = 0 if ctr + 1 > 63 else (sign_aligner >> np.uint64(ctr + 1)) & np.uint64(1)
        val = 2 * bit_value - 1
        # b_i^J = 2k_{i+1}^J - 1
        encoded_sign_aligner = np.insert(encoded_sign_aligner, 1, val)
    return encoded_sign_aligner


@preconditions(
    lambda multi_scalar: isinstance(multi_scalar, np.ndarray),
    # type of the scalars should be np.uint64
    lambda multi_scalar: all(isinstance(scalar, np.uint64) for scalar in multi_scalar),
    # verify that the values are within the expected range
    lambda multi_scalar: all((0 <= scalar < 2 ** 64) for scalar in multi_scalar),
    # verify that there is at least one odd scalar that can be used as the sign aligner
    lambda multi_scalar: any(list(map(lambda x: x & np.uint64(1), multi_scalar))),
    lambda base_point_order: isinstance(base_point_order, int),
)
def recode_multi_scalar_general_unoptimized(multi_scalar, base_point_order, print_debug=False):
    """
    General algorithm for recoding the multiscalar as described in the paper
    "Efficient and secure algorithms for GLV-based scalar multiplication and their implementation on GLV-GLS curves".
    :param base_point_order:
    :param multi_scalar: the multi-scalar
    :return:
    """

    # Determine the GLV dimension (m) and the length of the multi scalars
    m = len(multi_scalar)

    length = int(math.ceil(math.log(base_point_order, 2) / m)) + 1

    # Obtain sign aligner
    odd_scalars = list(map(lambda x: x & np.uint64(1), multi_scalar))
    sign_aligner_index = odd_scalars.index(True)
    sign_aligner = multi_scalar[sign_aligner_index]

    # Matrix that will store the recoded scalar in a nice-to-view structure.
    matrix_glv_sac = np.zeros((m, length))

    # Put multi scalars in mutable list that we can reuse throughout the computation
    multi_scalar_mut = multi_scalar.copy()

    # b_{l - 1}^J = 1
    matrix_glv_sac[sign_aligner_index, 0] = 1

    """
    replacing every sequence 00 .. 01 in the sign aligner by 1(-1)...(-1)(-1) (keeping the same number of digits) 
    """
    for ctr in range(length - 1):
        bit_value = 0 if ctr + 1 > 63 else (sign_aligner >> np.uint64(ctr + 1)) & np.uint64(1)
        val = 2 * bit_value - 1
        # b_i^J = 2k_{i+1}^J - 1
        matrix_glv_sac[sign_aligner_index, length - ctr - 1] = val

    for j in range(m):
        # We should not take the index of the sign aligner into account
        if j != sign_aligner_index:
            if print_debug:
                print("\nk_{} = {}\n".format(j, multi_scalar_mut[j]))
            for i in range(length):
                scalar = multi_scalar_mut[j]
                sign_aligner_val_i = np.int8(matrix_glv_sac[sign_aligner_index, length - i - 1])
                key_j_bit_0 = scalar & np.uint64(1)
                val_j_i = np.int8(sign_aligner_val_i * key_j_bit_0)
                # b_i^j = b_i^J * k_0^J
                if print_debug:
                    print('Iteration {}/{}'.format(i, length - 1))
                    print("b_{}^{} = b_{}^{} * k_0^{} = {}".format(i, j, i, sign_aligner_index, j, val_j_i))
                    print("k_0^{} = {}".format(j, key_j_bit_0))
                matrix_glv_sac[j, length - i - 1] = val_j_i
                # k_j = floor(k_j / 2) - floor(b_i^j / 2)
                val_j_i = math.floor(val_j_i / 2)
                multi_scalar_mut[j] = np.floor_divide(scalar, np.uint64(2))
                val_to_add = val_j_i * -1
                multi_scalar_mut[j] += np.uint64(val_to_add)

                # DEBUG STATEMENTS
                if print_debug:
                    print("k_{} = floor(k_{} / 2) - floor(b_{}^{} / 2) = ".format(j, j, i, j), multi_scalar_mut[j])
                    print("floor(b_{}^{} / 2) = {}\n".format(i, j, val_j_i))

    matrix_glv_sac = matrix_glv_sac.astype(np.int8)
    if print_debug:
        print(matrix_glv_sac)
    return matrix_glv_sac


"""
To invert this, we have a couple of options:
- Brute force: just generate random scalars and hope they will match the structured scalar you were looking for
- Inverse: inverse the function such that you can obtain the original scalar belonging to a scalar in structured form
- Constraint like: start with random scalars, but adapt once you see certain constraints are not met
As we know where it went wrong, we can calculate what the appropriate value would be.
"""


@preconditions(
    lambda multi_scalar: isinstance(multi_scalar, np.ndarray),
    lambda multi_scalar: all(isinstance(scalar, np.uint64) for scalar in multi_scalar),
    lambda multi_scalar: len(multi_scalar) == 4,
    lambda multi_scalar: all((0 <= scalar < 2 ** 64) for scalar in multi_scalar),
    lambda multi_scalar: any(list(map(lambda x: x & np.uint64(1), multi_scalar))),
)
def recode_multi_scalar_optimized(multi_scalar, output_in_matrix_format=False):
    """
    Input: Four positive integers a_i = (0, a_i[63], ..., a_i[0])_2 less than 2^{64} for 1 <= i <= 4 and with a1 being odd.
    :param multi_scalar: The multi-scalar
    :return: (d_{64}, ..., d_0) with 0 <= d_i < 16 (i.e. 4 bits values) formatted as a matrix with digit columns
    """

    """
    A bitshift of a numpy np.uint64 dtype with more than 63 bits (i.e. >> 64 or more) will give the original value back
    So we have to check this
    """
    # Store output
    signs = []
    masks = []
    multi_scalar_mut = multi_scalar[:]

    s64 = 1
    for j in range(64):
        v_j = 0
        # s_j = a_1[j + 1]
        a1_jth_plus_one_bit = np.uint64(0) if j + 1 > 63 else (multi_scalar_mut[0] >> np.uint64(j + 1)) & np.uint64(1)
        s_j = a1_jth_plus_one_bit
        for i in range(2, 5):
            ai_0th_bit = (multi_scalar_mut[i - 1] & np.uint64(1))
            # v_j = v_j + (a_i[0] << (i - 2))
            v_j = v_j + (ai_0th_bit << np.uint64(i - 2))
            # c = (a_1[j + 1] | a_i[0]) ^ a_1[j + 1]
            c = (a1_jth_plus_one_bit | ai_0th_bit) ^ a1_jth_plus_one_bit
            # a_i = (a_i >> 1) + c
            multi_scalar_mut[i - 1] >>= np.uint64(1)
            multi_scalar_mut[i - 1] += c
        signs.append(s_j)
        masks.append(v_j)

    # v_64 = a_2 + 2a_3 + 4a_4, which in essence calculates the value of the digit column v_64
    v_64 = multi_scalar_mut[1] + 2 * multi_scalar_mut[2] + 4 * multi_scalar_mut[3]

    # Construct output
    signs.append(s64)
    masks.append(v_64)
    # Reversed returns an iterator
    signs = reversed(signs)
    masks = reversed(masks)

    if not output_in_matrix_format:
        digit_columns = [(sign, mask) for sign, mask in zip(signs, masks)]
        # The tuple (s_{64}, v_{64}) should be the first element in the list
        digit_columns.reverse()
        return digit_columns

    else:
        # We have a digit column for each scalar (m = 4) and with the number of columns equal to the scalar length
        # (l = 64)
        matrix_glv_sac = np.zeros((4, 65), dtype=np.int8)
        matrix_glv_sac[0] = list(signs)
        for idx, mask in enumerate(masks):
            bit_0 = (np.uint64(mask) >> np.uint64(0)) & np.uint64(1)
            bit_1 = (np.uint64(mask) >> np.uint64(1)) & np.uint64(1)
            bit_2 = (np.uint64(mask) >> np.uint64(2)) & np.uint64(1)
            matrix_glv_sac[1, idx] = bit_0
            matrix_glv_sac[2, idx] = bit_1
            matrix_glv_sac[3, idx] = bit_2
        matrix_glv_sac = matrix_glv_sac.astype(np.int8)
        return matrix_glv_sac


def matrix_to_scalars(scalars_arranged_in_matrix: np.ndarray):
    """
    Convert a matrix with encoded scalars to a list of corresponding decimal values
    :param scalars_arranged_in_matrix: The recoded matrix
    :return: A list of decimal values reprenseting the values of the sub-scalars in the recoded matrix
    """
    scalars_vals = []
    for scalar in scalars_arranged_in_matrix:
        scalar_val = scalar_array_to_decimal(scalar)
        scalars_vals.append(scalar_val)
    return scalars_vals


def scalar_array_to_decimal(scalar):
    """
    Convert a recoded scalar in array format to its corresponding decimal value.
    :param scalar: The scalar as an array of 0's, 1's and -1's
    :return: The decimal value represented by the scalar array
    """
    power_of_two_array = list(reversed([1 << i for i in range(len(scalar))]))
    scalar_val = [int(x * y) for x, y in zip(scalar, power_of_two_array)]
    scalar_val = int(sum(scalar_val))
    return scalar_val


def scalars_fit_in_uint64(recoded_matrix, sign_aligner_index=0):
    """
    Given the recoded matrix and the index of the sign aligner, determines whether the decimal values correpsonding
    to the recoded sub-scalars (and also the sign aligner itself) fit in an np.uint64 data type.
    :param recoded_matrix: The matrix containing the recoded sub-scalars
    :param sign_aligner_index: The index of the sign-aligner
    :return: True if all recoded sub-scalars (including the sign-aligner) can fit in the np.uint64 data type, False
    otherwise
    """
    for row in range(recoded_matrix.shape[0]):
        scalar_array = recoded_matrix[row]
        # Apply signs of the sign aligner to the scalar and verify whether it fits in a unsigned 64 bit integer
        scalar_array = scalar_array if row == sign_aligner_index else np.multiply(scalar_array,
                                                                                  recoded_matrix[sign_aligner_index])
        scalar_val = scalar_array_to_decimal(scalar_array)
        if 0 <= scalar_val <= np.iinfo(np.uint64).max:
            continue
        else:
            return False
    return True


def get_valid_recoded_matrix(expected_digit_columns, length):
    """
    Given a 2d array of wanted digit columns, gives back the scalars in matrix form that will produce these digit columns.
    :param length: The fixed length of the recoded matrix (i.e the width or the number of columns in this matrix)
    :param expected_digit_columns: The digit column that are wanted in the recoded matrix
    :return: The scalars that will produce the corresponding recoded matrix with wanted digit columns (formatted as a matrix)
    """
    # print(expected_digit_columns)
    shape = expected_digit_columns.shape

    if len(shape) != 2:
        raise Exception("We expect a 2D matrix.")

    (rows, cols) = shape
    # First element indicates number of rows, second element number of columns

    # Create recoding matrix with the appropriate number of columns and rows
    padding_length = length - cols
    padding_cols = np.zeros((rows, padding_length))
    recoded_matrix = np.concatenate((expected_digit_columns, padding_cols), axis=1)

    # Some checks that the input was valid

    if not _scalars_could_fit_in_uint64(recoded_matrix, cols):
        # Assuming all "blank" signs are negative and, can they ever fit in uint64?
        # If not, we do not bother to find a compliant recoded matrix as it does not exist
        return recoded_matrix, False
    if recoded_matrix[0, 0] != 1:
        # raise Exception("The first bit of the sign-aligner must be zero")
        return recoded_matrix, False
    if not _verify_signs(recoded_matrix):
        # raise Exception("Signs of the sign-aligner do not match with the signs of the values in the recoded-scalars")
        return recoded_matrix, False
    if not _verify_positive_sub_scalars(recoded_matrix):
        # raise Exception("Some scalars do not have a positive value")
        """
        Note that if the scalar has a positive value as represented by the wanted digit columns,
        it will always stay positive. The same applies for the negative case. However, this negative case
        can never happen as the the last digit column in the recoded matrix always has a positive sign.
        """
        return recoded_matrix, False

    # Probability of a positive bit in free-to-fill-in positions in the padding of the sign-aligner
    prob_pos = 1. / 5

    # Fill the padding for the sign aligner with 1's and -1's at random
    recoded_sign_aligner_padding = np.random.choice([1, -1], size=(padding_length,), p=[prob_pos, 1 - prob_pos])
    # recoded_sign_aligner_padding = [-1] * padding_length
    # Add this padding to the sign-aligner in the recoded matrix
    recoded_matrix[0, cols:] = recoded_sign_aligner_padding

    # Do the same for the padding of the sub-scalars (which is a matrix instead of a single array)
    recoded_sub_scalars_padding = np.random.choice([1, 0], size=(rows - 1, padding_length), p=[prob_pos, 1 - prob_pos])
    # recoded_sub_scalars_padding = [1] * padding_length
    recoded_matrix[1:rows, cols:] = recoded_sub_scalars_padding

    # Interpret the recoded matrix as int8 type (instead of float64)
    recoded_matrix = recoded_matrix.astype(np.int8)

    valid_decomposition, recoded_matrix = _is_valid_decomposition(recoded_matrix)
    valid_decomposition &= scalars_fit_in_uint64(recoded_matrix)

    attempts = 0

    while not valid_decomposition:
        recoded_sign_aligner = recoded_matrix[0]
        sign_aligner_val = scalar_array_to_decimal(recoded_sign_aligner)
        # Verify that the value of the sign-aligner is odd
        assert sign_aligner_val & 1
        # Verify that the value of the sign aligner fits in a 64 bit unsigned integer
        if not sign_aligner_val <= np.iinfo(np.uint64).max or attempts >= 1000:
            recoded_matrix[0, cols:] = np.random.choice([1, -1], size=(padding_length,), p=[prob_pos, 1 - prob_pos])
            attempts = 0
            continue
        for row in range(1, recoded_matrix.shape[0]):
            is_positive_sub_scalar = first_value_positive(np.multiply(recoded_matrix[row], recoded_sign_aligner))
            if not is_positive_sub_scalar:
                # Randomize padding of scalar
                while True:
                    recoded_matrix[row, cols:] = np.random.choice([0, 1], size=(padding_length,), p=[9. / 10, 1. / 10])
                    sub_scalar_val = scalar_array_to_decimal(np.multiply(recoded_matrix[row], recoded_sign_aligner))
                    if 0 < sub_scalar_val <= np.iinfo(np.uint64).max:
                        break
        valid_decomposition, recoded_matrix = _is_valid_decomposition(recoded_matrix)
        valid_decomposition &= scalars_fit_in_uint64(recoded_matrix)
        attempts += 1
        # If this takes too long, we should randomize the sign-aligner.
    # Apply the sign-aligner to the rows such that the signs match
    for row in range(1, recoded_matrix.shape[0]):
        recoded_matrix[row] *= recoded_matrix[0]
    return recoded_matrix, True


def _is_valid_decomposition(recoded_matrix):
    """
    Cheks whether the current recoding matrix is valid with  respect to positive sub-scalars.
    :param recoded_matrix: The recoded matrix
    :param padding_length: The padding length (the amount of padding compared to the number of digit columns given)
    :return:
    """
    recoded_sign_aligner = recoded_matrix[0]
    valid_decomposition = True
    # Loop through the rows (i.e the recoded scalars in our recoded matrix) but not sign-aligner
    for row in range(1, recoded_matrix.shape[0]):
        # Multiply the recoded multi scalar with the sign aligner
        recoded_matrix[row] *= recoded_sign_aligner
        # Calculate the original value of the scalar
        # This method seems to overflow, so we just check the first sign of the first bit we encounter
        # scalar_val = recoded_matrix[i].dot(2 ** np.arange(recoded_matrix[i].size)[::-1])
        if not first_value_positive(recoded_matrix[row]):
            valid_decomposition &= False
        recoded_matrix[row] = np.abs(recoded_matrix[row])
    return valid_decomposition, recoded_matrix


def _verify_signs(recoded_matrix):
    """
    Verify whether the signs of the sign-aligner correspond with corresponding values in the recoded scalars in the
    recoded matrix.
    :param recoded_matrix: The recoded matrix corresponding the sign-aligner at the first row and the recoded sub-scalars
    in the remaining rows.
    :return:
    """
    sign_aligner = recoded_matrix[0]
    # Loop through the rows (i.e the recoded scalars in our recoded matrix)
    for row in range(1, recoded_matrix.shape[0]):
        recoded_sub_scalar = recoded_matrix[row]
        for val, sign in zip(recoded_sub_scalar, sign_aligner):
            # The signs are equal when either the value is zero or both non-zero values have the same sign
            equal_signs = np.signbit(sign) == np.signbit(val) or val == 0
            if not equal_signs:
                return False
    return True


def first_value_positive(array):
    """
    Check whether the first non-zero value in an array is positive (i.e. equals 1)
    :param array: An integer array
    :return: True if the first non-zero element is 1, false otherwise
    """
    positive_val_indices = np.argwhere(array == 1)
    negative_val_indices = np.argwhere(array == -1)
    if len(positive_val_indices) == 0 and len(negative_val_indices) == 0:
        return True
    if len(positive_val_indices) > 0 and len(negative_val_indices) == 0:
        return True
    if len(positive_val_indices) == 0 and len(negative_val_indices) > 0:
        return False
    positive_before_negative = positive_val_indices[0, 0] < negative_val_indices[0, 0]
    return positive_before_negative


def _verify_positive_sub_scalars(recoded_matrix):
    """
    Check whether the sub-scalars represented in the recoded matrix are all positive.
    :param recoded_matrix:
    :return:
    """
    all_positive_scalars = True
    sign_aligner = recoded_matrix[0]
    for row in range(1, recoded_matrix.shape[0]):
        all_positive_scalars &= first_value_positive(recoded_matrix[row])
        if not all_positive_scalars:
            return False
    return True


def _scalars_could_fit_in_uint64(recoded_matrix, nr_of_fixed_cols):
    """
    Given the number of fixed digit columns (starting from d_64 and s_64), check whether it is possible
    to fit all of the scalars in an unsigned 64 bit integer.
    :param recoded_matrix: The recoded matrix
    :param nr_of_fixed_cols: The number of fixed digit columns
    :return: True if the scalars values in the recoded matrix could fit in an uint64 by filling in the
    unfixed digit columns with negative values, False otherwise.
    """
    for row in range(recoded_matrix.shape[0]):
        scalar = recoded_matrix[row]
        scalar_val = scalar_array_to_decimal(scalar)
        if scalar_val == 0:
            continue
        if scalar_val < 0:
            return False
        # As know that the scalar must be positive, we can deterimee if it can fit in an uint64 by
        # filling in the remaining entries (where we assume that the sign will be negative)
        tmp_scalar = scalar[:nr_of_fixed_cols]
        nr_of_unfixed_cols = len(scalar) - nr_of_fixed_cols
        tmp_scalar = np.append(tmp_scalar, [-1] * nr_of_unfixed_cols)
        tmp_scalar_val = scalar_array_to_decimal(tmp_scalar)
        if 0 <= tmp_scalar_val <= np.iinfo(np.uint64).max:
            continue
        else:
            return False
    return True


@preconditions(
    lambda value: 0 <= value <= 2 ** 3 - 1
)
def generate_digit_column_for_value(value, sign):
    """
    Generate the digit column for a given value.
    These digit columns are used to obtain recoded matrices for which we want to retrieve the original scalar that
    resulted in this recoded matrix. NOTE: for digit column d_64, the sign should be positive!
    :param value: The value of the digit column
    :param sign: The sign of the digit column
    :return:
    """
    d_i_0 = (value & 1) * sign
    d_i_1 = ((value >> 1) & 1) * sign
    d_i_2 = ((value >> 2) & 1) * sign
    digit_column = np.array(
        [[sign],
         [d_i_0],
         [d_i_1],
         [d_i_2]
         ]
    )
    return digit_column


@preconditions(
    lambda recoded_matrix: isinstance(recoded_matrix, np.ndarray),
)
def interpret_recoded_matrix(recoded_matrix):
    # First row in the matrix contains the signs
    signs = recoded_matrix[0]

    # Construct values represented in the digit columns
    digit_column_values = []
    for col in range(recoded_matrix.shape[1]):
        # Access i-th column in the recoded matrix
        digit_column_i = recoded_matrix[:, col]
        # First element is the sign, which we do not need
        digit_column_i = digit_column_i[1:]
        # As digit column values are stored from last row to second-first row in the current row (as a binary number)
        # we need to reverse the list
        digit_column_i = list(reversed(digit_column_i))
        # Now interpret digit column as binary number (also make sure all digits are positive
        digit_column_val = scalar_array_to_decimal(np.abs(digit_column_i))
        digit_column_values.append(digit_column_val)

    # reverse lists such that we can write the main loop of the scalar multiplication exactly as presented in the paper
    signs = list(reversed(signs))
    digit_column_values = list(reversed(digit_column_values))
    return signs, digit_column_values


if __name__ == "__main__":
    scalar = 45340693952846959691828758919901861485551069196368784374246908835529884608377
    recoded_scalar = np.asarray([10462993606773094929, 6269064062689783238, 7932392730760724259, 8353231089421084786],
                                dtype=np.uint64)
    recoded_matrix = recode_multi_scalar_general_unoptimized(recoded_scalar, 2 ** 256)
    sign_alginer = recoded_matrix[0]
    dec_val = scalar_array_to_decimal(recoded_matrix[1])
    todo = 1
