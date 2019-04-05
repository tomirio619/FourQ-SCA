import itertools
import struct
from binascii import hexlify
from typing import *

import numpy as np

valid_encoding_types = Union[
    np.int32, np.int16, np.int8, np.float32, np.bool, bytes, bytearray, str, None]


class TraceSetCoding(object):
    trace_set_coding_objects = {
        "Trace": (1, {"NT": 0x41,
                      "NS": 0x42,
                      "SC": 0x43,
                      "DS": 0x44,
                      "TS": 0x45,
                      "GT": 0x46,
                      "DC": 0x47,
                      "XO": 0x48,
                      "XL": 0x49,
                      "YL": 0x4A,
                      "XS": 0x4B,
                      "YS": 0x4C,
                      "TO": 0x4D,
                      "LS": 0x4E
                      }, 0),
        "Scope": (2, {"RG": 0x55,
                      "CL": 0x56,
                      "OS": 0x57,
                      "II": 0x58,
                      "AI": 0x59
                      }, 0),
        "Filter": (3, {"FT": 0x5A,
                       "FF": 0x5B,
                       "FR": 0x5C
                       }, 0),
        "Clock": (4, {"EU": 0x60,
                      "ET": 0x61,
                      "EM": 0x62,
                      "EP": 0x63,
                      "ER": 0x64,
                      "RE": 0x65,
                      "EF": 0x66,
                      "EB": 0x67
                      }, 0),
        "Misc": (4, {"TB": 0x5F
                     }, 0),
    }

    def __init__(self):
        self.content = bytearray()
        self.extension = ".trs"
        # Assign header dictionaries to variables for easy use
        self.trace_tags = self.trace_set_coding_objects['Trace'][1]
        self.scope_tags = self.trace_set_coding_objects['Scope'][1]
        self.filter_tags = self.trace_set_coding_objects['Filter'][1]
        self.clock_tags = self.trace_set_coding_objects['Clock'][1]
        self.misc_tags = self.trace_set_coding_objects['Misc'][1]

    def _encode_tlv_triple(self, tag: int, length: int, value: valid_encoding_types,
                           additional_length_bytes: Optional[Union[bytearray, bytes]]) -> bytearray:
        """
        A TLV (Tag, Length, Value) structure is used for the file header.
        This method converts this TLV structure to the appropriate bytes (according to the specification).
        See Appendix K (Trace set coding) of the Inspector manual for more information.
        :param additional_length_bytes: if the msb of the length byte is 1, then additional length bytes are used to
        specify the total length of the value.
        :param tag: The tag
        :param length: The object length in number of bytes.
        :param value: The content of the object. It is stored in the subsequent number of bytes, indicated by length.
        :return: The byte-encoded TLV triple
        """
        byte_content = bytearray()
        byte_content.extend(struct.pack("<b", tag))
        # convert the length to bytes in little endian format (LSB).
        # @See https://docs.python.org/2/library/struct.html
        """
        The object coding always starts with the tag byte. The object length is coded in one or more bytes.
        If bit 8 (msb) is set to '0', the remaining 7 bits indicate the length of the object. If bit 8 is
        set to '1', the remaining 7 bits indicate the number of additional bytes in the length field. These
        additional bytes define the length in little endian coding (LSB first).
        """
        length_in_bytes = bytearray()
        # if the most significant bit becomes set, we need to change the byte format
        if -128 <= length < 0:
            # We need additional bytes to represent the length of the object
            # determine number of bytes needed to represent the length
            nr_of_additional_length_bytes = length & 0x7F
            length_in_bytes.extend(bytearray(struct.pack("<b", length)))
            length_in_bytes.extend(additional_length_bytes)
            # Most significant bit not set, just follow normal convention
        elif 0 <= length < 127:
            # Note that network order (i.e. LSB or MSB) does not matter, as we only have one byte which represents the
            # length!
            length_in_bytes = bytearray(struct.pack("b", length))
        else:
            # See the exception hierarchy here: https://docs.python.org/3/library/exceptions.html#exception-hierarchy
            raise Exception(
                "The length should a value between -128 and 127 (i.e. a 8-bit integer). Use the np.int8 data type")
        # Append the length bytes to our byte content
        byte_content.extend(length_in_bytes)

        #  The end of the header does not make use of the value, this checks whether this is the case
        if value is not None:
            value_in_bytes = self._encode_value_bytes(value)
            byte_content.extend(value_in_bytes)
        return byte_content

    def _encode_value_bytes(self, value: valid_encoding_types) -> bytearray:
        """
        Encode the value in the TLV structure to bytes, according to the specification.
        :param value: The value
        :return: The value converted to a string of corresponding bytes.
        """
        # Time to convert the data to bytes. First we check what the type of the data is
        if isinstance(value, np.int32):
            value_bytes = struct.pack("<l", value)
        elif isinstance(value, np.int16):
            value_bytes = struct.pack("<h", value)
        elif isinstance(value, np.int8):
            value_bytes = struct.pack("<b", value)
        elif isinstance(value, np.float32):
            # float has always length 4
            value_bytes = struct.pack("<f", value)
        elif isinstance(value, np.bool):
            value_bytes = struct.pack("<?", value)
        elif isinstance(value, bytearray) or isinstance(value, bytes) or isinstance(value, str):
            # format is bytes already
            value_bytes = value
        else:
            print("Unknown type for the value. Its type is: {}".format(type(value)))
            raise TypeError("Encountered an unknown type")
        return bytearray(value_bytes)

    def _get_sample_coding(self, sample_type, sample_length) -> bytearray:
        """
        Get the byte encoding that specifies how the sample is coded
        :param sample_type: integer (0) or floating point (1)
        :param sample_length: Sample length in bytes (valid values are 1, 2, 4)
        :return: The sample coding as a byte
        """
        if sample_type not in {0, 1}:
            raise AssertionError("The sample type should be integer (0) or floating point (1)")
        if sample_length not in {1, 2, 4}:
            raise AssertionError("Valid values for the sample length are 1, 2 and 4")
        sample_coding = np.int8(0)
        sample_coding |= np.int8((sample_type << 4))
        sample_coding |= np.int8(sample_length)
        sample_coding = np.int8(sample_coding)
        return bytearray(struct.pack("B", sample_coding))

    def _encode_header(self, nr_of_traces: int, nr_of_samples_per_trace: int,
                       sample_coding: Union[np.int8, bytearray], data_bytes_per_trace=0,
                       title_space_reserved_per_trace=20, global_trace_title="FourQ power trace") -> bytearray:
        """
        Encode the header usd in the Trace Set Encoding
        :param nr_of_traces: The number of traces
        :param nr_of_samples_per_trace: The number of samples per trace
        :param sample_coding: The sample encoding
        :param data_bytes_per_trace: The number of data bytes per trace
        :param title_space_reserved_per_trace: Title space reserved per trace
        :param global_trace_title: The global trace title
        :return:
        """
        header = bytearray()
        # BEGIN of header
        header.extend(self._encode_tlv_triple(self.trace_tags['NT'], 4, np.int32(nr_of_traces), bytearray()))
        header.extend(self._encode_tlv_triple(self.trace_tags['NS'], 4, np.int32(nr_of_samples_per_trace), bytearray()))
        header.extend(self._encode_tlv_triple(self.trace_tags['SC'], 1, sample_coding, bytearray()))
        header.extend(self._encode_tlv_triple(self.trace_tags['DS'], 2, np.short(data_bytes_per_trace), bytearray()))
        header.extend(self._encode_tlv_triple(self.trace_tags['TS'], 1, np.int8(title_space_reserved_per_trace),
                                          bytearray()))
        global_trace_title_bytes = bytearray(global_trace_title, "utf8")
        header.extend(self._encode_tlv_triple(self.trace_tags['GT'], len(global_trace_title_bytes),
                                          global_trace_title_bytes, bytearray()))
        # Mark end of header
        header.extend(self._encode_tlv_triple(self.misc_tags['TB'], 0, None, bytearray()))
        # END of header
        # print(hexlify(header))
        return header

    def _encode_trace(self, samples: np.ndarray, sample_data_type: int, sample_length: int, title_space_len: int,
                      title: str,
                      data_bytes: bytearray) -> bytearray:
        """
        Every trace is preceded by a Title Space (TS) (ASCII value of a space is 32_10 or 20_16).
        The title space can be used to name the trace.
        How long this name can be depends on the title space reserved per trace (TS), which is
        The data space indicates the length of cryptographic data included in each trace).
        Each trace consists of a number of samples.
        The sample coding specifies what the format of the trace is (either integer or floating point), and what the
        sample length is (in bytes).
        :param title_space_len:
        :param title:
        :param data_bytes:
        :param data_space:  Length of cryptographic data included in the trace (e.g. 128 bit)
        :param samples: The samples in the trace
        :param sample_data_type: The data type of the samples: integer (0) or floating point (1)
        :param sample_length: The length of each sample
        """
        if sample_data_type not in [0, 1]:
            raise AssertionError("The sample type should be integer (0) or floating point (1)")
        if sample_length not in [1, 2, 4]:
            raise AssertionError("Valid values for the sample length are 1, 2 and 4")
        # Add the title into the title space (also check that it does not exceed the number of bytes available for this)
        encoded_trace = bytearray()
        if title is None:
            # If there is not title specified, we fill the title space with spaces
            encoded_trace.extend((bytearray([0x20] * title_space_len)))
        else:
            # Convert string to bytes
            title_as_bytes = bytes(title, 'utf-8')
            encoded_title = (bytearray([0x20] * title_space_len))
            # See https://stackoverflow.com/questions/4013230/how-many-bytes-does-a-string-have
            if len(title_as_bytes) < len(encoded_title):
                # see https://stackoverflow.com/questions/10633881/how-to-copy-a-python-bytearray-buffer
                # As the num
                encoded_title[0:len(title_as_bytes)] = title_as_bytes
            else:
                encoded_title = title_as_bytes[0:title_space_len]

            encoded_trace.extend(encoded_title)

        # Add the data bytes
        if data_bytes is not None:
            encoded_trace.extend(data_bytes)
        # Add the samples
        for sample in np.nditer(samples):
            encoded_sample = self._encode_sample(sample, sample_data_type, sample_length)
            encoded_trace.extend(encoded_sample)
        return encoded_trace

    def _encode_sample(self, sample: int, sample_data_type: int, sample_length: int):
        """
        Encode the sample based on the provided data type and sample length
        :param sample: The sample
        :param sample_data_type: The data type to store the sample in: integer (0) or floating point (1)
        :param sample_length: The length of the sample in bytes
        :return: The sample encoded according to the provided arguments
        """
        encoded_sample = bytearray()
        # Determine correct encoding
        if sample_data_type == 0:
            # Encode as integer
            if sample_length == 1:
                encoded_sample.extend(struct.pack("<b", np.int8(sample)))
            elif sample_length == 2:
                encoded_sample.extend(struct.pack("<h", np.int16(sample)))
            elif sample_length == 4:
                encoded_sample.extend(struct.pack("<i", np.int32(sample)))
        elif sample_data_type == 1:
            # Encode as float
            if 1 <= sample_length <= 2:
                raise Exception("A sample encoded as a float needs to have a sample length of 4 bytes")
            # elif sample_length == 2:
            #     encoded_sample.extend(struct.pack("<e", np.float16(sample)))
            elif sample_length == 4:
                encoded_sample.extend(struct.pack("<f", np.float32(sample)))

        return encoded_sample

    def to_trs_format(self, traces: List[np.array],
                      traces_data_bytes: Union[List[bytearray], bytearray, None], trace_names: list,
                      samples_per_trace: int, sample_type: int, sample_length: int, nr_of_data_bytes: int = 0,
                      global_trace_title: Optional[str] = "FourQ power trace") -> bytearray:
        """
        :param traces: The traces
        :param traces_data_bytes:  The data bytes related to the corresponding trace (i.e. which were used in the
        computation of the cryptographic system). The bytes should be in big endian format!
        :param trace_names: A list with names for each trace
        :param samples_per_trace: The number of samples per trace
        :param sample_type: The type of the sample
        :param sample_length: The number of bytes a simple consists of
        :param nr_of_data_bytes: The number of data bytes stored with each trace
        :param global_trace_title: The global trace title
        :return: 
        """
        # Determine trace name that needs the most bytes to be represented,
        # this will be the title space reserved per trace
        if trace_names is None or len(trace_names) == 0:
            title_space_len = 20
        else:
            longest_name = max(trace_names, key=lambda name: len(name.encode("utf8")))
            title_space_len = len(longest_name.encode("utf8"))

        trs_file_content = bytearray()
        sample_coding = self._get_sample_coding(sample_type, sample_length)
        # Encode the header
        nr_of_traces = len(traces)

        encoded_header = self._encode_header(nr_of_traces, samples_per_trace, sample_coding, nr_of_data_bytes,
                                             title_space_len)
        trs_file_content.extend(encoded_header)
        for trace, trace_title, trace_data_bytes in itertools.zip_longest(traces, trace_names, traces_data_bytes):
            trace_encoded = self._encode_trace(trace, sample_type, sample_length, title_space_len, trace_title,
                                               trace_data_bytes)
            trs_file_content.extend(trace_encoded)
        return trs_file_content
