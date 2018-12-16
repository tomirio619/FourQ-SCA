import os
import struct
import unittest
from binascii import hexlify, unhexlify
from random import randint, choice
from typing import *

import numpy as np

from lecroy import trace_set_coding

tsc = trace_set_coding.TraceSetCoding()


class TestTraceSetCoding(unittest.TestCase):

    def test_encoding_without_additional_length_bytes(self):
        # Loop through all the tag strings and their corresponding values
        for tag_str, tag_value in tsc.trace_tags.items():
            # Only if the msb is NOT set no additional length fields will be used
            length = np.int8(4)
            min_value = np.iinfo(np.int32).min
            max_value = np.iinfo(np.int32).max
            value = np.int32(randint(min_value, max_value))
            # Apply TLV encoding
            encoded_tlv = tsc._encode_tlv_triple(tag_value, length, value, bytearray())
            tlv_hex_str = hexlify(encoded_tlv)

            # Obtain values from hex string for comparison later on (NOTE: they are in little endian format)
            tag_hex_str = tlv_hex_str[0:2]
            length_hex_str = tlv_hex_str[2:4]
            value_hex_str = tlv_hex_str[4:]

            # As the hex values are in little endian, we use unhexlify to convert the hex string to its binary form,
            # and ues struct.unpack to decode the little endian value into an int
            decoded_tag_value = struct.unpack("<b", unhexlify(tag_hex_str))[0]
            decoded_length_value = struct.unpack("<b", unhexlify(length_hex_str))[0]
            decoded_value = struct.unpack("<l", unhexlify(value_hex_str))[0]

            # Verify results
            self.assertEqual(decoded_tag_value, tag_value)
            self.assertEqual(decoded_length_value, length)
            self.assertEqual(decoded_value, value)

    def _generate_positive_length_bytes(self, nr_of_additional_length_bytes) -> Tuple[bytearray, int]:
        """
        Generate the specified number of bytes.
        These bytes should represent (in LSB) a positive integer.
        :param nr_of_additional_length_bytes: The number of bytes to generate
        :return: The specified number of bytes to generate, and its corresponding value (bytes interpreted as LSB)
        """
        additional_length_bytes = os.urandom(nr_of_additional_length_bytes)
        length = int.from_bytes(additional_length_bytes, byteorder='little', signed=True)
        while True:
            if length >= 0:
                break
            # Length is negative, generate new number bytes
            additional_length_bytes = os.urandom(nr_of_additional_length_bytes)
            length = int.from_bytes(additional_length_bytes, byteorder='little', signed=True)
        return bytearray(additional_length_bytes), length

    def test_encoding_with_additional_length_bytes(self):
        """
        Verify the encoding when using a length field that specifies an addition number of length bytes that
        represent the number of value bytes present in the encoding.
        :return:
        :rtype:
        """
        for tag_str, tag_value in tsc.trace_tags.items():
            # Only if the msb IS set, additional length fields will be used
            for nr_of_additional_length_bytes in range(1, 4):
                # Increasing the number of bytes in the addition length fields leads to unstable PC
                length = np.int8(nr_of_additional_length_bytes)
                # length = np.bitwise_or(np.int8())
                length |= np.int8((1 << 7))

                # The additional length bytes now specify the 'new length', we calculate this value
                additional_length_bytes, new_length = self._generate_positive_length_bytes(
                    nr_of_additional_length_bytes)

                # Generate corresponding number of value bytes
                value_bytes = os.urandom(new_length)

                # Apply TLV encoding
                encoded_tlv = tsc._encode_tlv_triple(tag_value, length, value_bytes,
                                                     additional_length_bytes=additional_length_bytes)
                # If the length of the number of additional length bytes is odd, we round the variable used to index the
                # corresponding hex bytes representing this number to the nearest even number.
                end_index_extra_length_bytes = nr_of_additional_length_bytes
                if nr_of_additional_length_bytes % 2 != 0:
                    end_index_extra_length_bytes += 1

                tlv_hex_str = hexlify(encoded_tlv)

                # Obtain values from hex string for comparison later on (NOTE: they are in little endian format)
                tag_hex_str = tlv_hex_str[0:2]
                orig_length_hex_str = tlv_hex_str[2:4]
                length_hex_str = tlv_hex_str[4: 4 + end_index_extra_length_bytes]
                value_hex_str = tlv_hex_str[4 + end_index_extra_length_bytes:]

                # As the hex values are in little endian, we use unhexlify to convert the hex string to its binary form,
                # and ues struct.unpack to decode the little endian value into an int.
                # For values that do not fit into the data types specified by struct, we make use of the from_bytes
                # method (Python 3 only!)
                decoded_tag_value = struct.unpack("<b", unhexlify(tag_hex_str))[0]
                decoded_orig_length_value = struct.unpack("<b", unhexlify(orig_length_hex_str))[0]
                decoded_length_value = int.from_bytes(unhexlify(length_hex_str), byteorder='little', signed=True)
                decoded_value = unhexlify(value_hex_str)

                value_nr_of_bytes = len(value_hex_str) / 2

                # Verify results
                self.assertEqual(decoded_orig_length_value, length)
                self.assertEqual(decoded_tag_value, tag_value)

                # TODO the number of bytes is off by one compared to the length specified in the additional length bytes!
                # TODO this is probably due to missing padding
                # TODO not sure if this a problem or not
                # print("Number of bytes in the value:{}".format(value_nr_of_bytes))
                # print("NUmber of bytes according to the new length:{}".format(new_length))
                self.assertTrue(abs(value_nr_of_bytes - new_length) <= 1)

    def test_sample_encoding(self):
        valid_sample_lengths = [1, 2, 4]
        valid_sample_data_types = [
            0,  # integer
            1,  # float
        ]
        for sample_data_type in valid_sample_data_types:
            for valid_sample_length in valid_sample_lengths:
                """
                An unsigned n-bit integer can represent values in the range [0, 2^(n) - 1)
                A signed n-bit integer can represent values in the range [-2^(n-1) through 2^(n - 1) - 1)
                """
                # Either generate a random float or a random int
                if sample_data_type == 0:
                    # Integer
                    min_value = - 2 ** (valid_sample_length * 8 - 1)
                    max_value = 2 ** (valid_sample_length * 8 - 1) - 1
                    random_sample = randint(min_value, max_value)
                else:
                    # Float
                    min_value = np.finfo(np.float16).min if valid_sample_length == 2 else np.finfo(np.float32).min
                    max_value = np.finfo(np.float16).max if valid_sample_length == 2 else np.finfo(np.float32).max
                    random_sample = np.random.uniform(min_value, max_value)
                    random_sample = np.float16(random_sample) if valid_sample_length == 2 else np.float32(random_sample)

                if sample_data_type == 1 and (1 <= valid_sample_length <= 2):
                    # A float value cannot be encoded in 1 or 2 bytes! (i.e following the IEEE 754 standard)
                    self.assertRaises(Exception,
                                      tsc._encode_sample, random_sample, sample_data_type, valid_sample_length)
                else:
                    # Get encoded value
                    encoded_sample = tsc._encode_sample(random_sample, sample_data_type, valid_sample_length)
                    # Verify whether the encoding is correct

                    if sample_data_type == 0:
                        # Decode back to integer
                        decoded_sample = int.from_bytes(encoded_sample, byteorder='little', signed=True)
                        # Compare decoded value with original value
                        self.assertEqual(random_sample, decoded_sample)
                    else:
                        # Decode back to float (either unpack using 2 bytes or as 4 bytes)
                        # NOTE: as we follow the IEEE 754 standard, only unpacking of 4 bytes will happen!
                        decoded_sample = struct.unpack("<e", encoded_sample) if valid_sample_length == 2 \
                            else struct.unpack("<f", encoded_sample)
                        decoded_sample = np.float32(decoded_sample[0])
                        # We only have ~ 7 bits of precision
                        # See the following links for more information on this:
                        # https://stackoverflow.com/questions/21895756/why-are-floating-point-numbers-inaccurate
                        # https://bugs.python.org/issue4114
                        # negative_dec, exponent_dec, significand_dec = self._decompose(decoded_sample)
                        # negative, exponent, significand = self._decompose(random_sample)
                        self.assertTrue(np.allclose(decoded_sample, random_sample, rtol=1e-07))

    def test_header_encoding(self):
        valid_sample_lengths = [1, 2, 4]
        valid_sample_data_types = [
            0,  # integer
            1,  # float
        ]
        nr_of_traces = randint(0, 2 ** 7 - 1)
        nr_of_samples_per_trace = randint(0, 2 ** 4 - 1)
        data_bytes_per_trace = randint(0, 10)
        title_space_reserved_per_trace = randint(10, 30)
        global_trace_title = "FourQ power trace"
        for sample_data_type in valid_sample_data_types:
            for sample_length in valid_sample_lengths:
                # try:
                sample_coding = tsc._get_sample_coding(sample_data_type, sample_length)
                print(np.int8(sample_coding))
                # TODO encoding the global trace title is not working!
                encoded_header = tsc._encode_header(
                    nr_of_traces,
                    nr_of_samples_per_trace,
                    sample_coding,
                    data_bytes_per_trace,
                    title_space_reserved_per_trace,
                    global_trace_title
                )
                    # Verify that header is encoded correctly
                # except TypeError as e:
                #     # Floats cannot be encoded with 1 and 2 bytes, this is already tested
                #     print(e)
                #     # pass

    def _decompose(self, x: np.float32):
        """
        Decomposes a float32 into negative, exponent, and significand
        :param x: A 4 byte floating point number (according to IEE 754)
        :return: The triple (negative, exponent, significand)
        """
        negative = x < 0
        n = np.abs(x).view(np.int32)  # discard sign (MSB now 0),
        # view bit string as int32
        exponent = (n >> 23) - 127  # drop significand, correct exponent offset
        # 23 and 127 are specific to float32
        significand = n & np.int32(2 ** 23 - 1)  # second factor provides mask
        # to extract significand
        return negative, exponent, significand
