import unittest
from binascii import hexlify

from fourq_hardware import fourq_rom_constants
from sakura_g.ftdi_interface import SaseboGii

sakura = None


class TestFpgaIO(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        try:
            global sakura
            sakura = SaseboGii()
        except Exception as e:
            print("Unable to connect to the control FPGA")

    @classmethod
    def tearDownClass(cls):
        sakura.disconnect()

    def test_fpga_read_very_simple(self):
        """
        Test the reading from a address that contains a hardcoded value
        """
        read_address = 0xFFFF
        expected_read = 0x1337
        result = hexlify(sakura.read(read_address))
        self.assertEqual(int(result, 16), expected_read)

    def test_fpga_read_write_simple(self):
        """
        Simple read and write tests for the SAKURA_G FPGA
        :return:
        """
        test_value = 0x1335
        test_value_msb = (test_value >> 8) & 0xFF
        test_value_lsb = test_value & 0xFF
        main_fpga_internal_address = 0x0140

        sakura.write(main_fpga_internal_address, test_value_msb, test_value_lsb)
        read_result = hexlify(sakura.read(0x0296))
        self.assertEqual(test_value, int(read_result, 16))

        d_imag_lower = "0000000000000142"
        d_imag_upper = "00000000000000e4"
        d_imag_rom_address = 0x1F

        # Write and read values
        sakura.write64(d_imag_lower, d_imag_rom_address, main_fpga_internal_address,
                       is_upper_half=False)
        read_result = sakura.read_internal_data_register()
        self.assertEqual(int(d_imag_lower, 16), int(read_result, 16))

        sakura.write64(d_imag_upper, d_imag_rom_address, main_fpga_internal_address,
                       is_upper_half=False)
        read_result = sakura.read_internal_data_register()
        self.assertEqual(int(d_imag_upper, 16), int(read_result, 16))

    def test_fpga_read_write(self):
        """
        Write all the constants used in FourQ to the FPGA and read them back to verify.
        """

        # Verify writing to ROM
        for lower_half, upper_half, addr in fourq_rom_constants.rom_values:
            sakura.write64(lower_half, addr, 0x0140, is_upper_half=False)
            read_result = sakura.read_internal_data_register()
            self.assertEqual(lower_half, read_result)
            sakura.write64(upper_half, addr, 0x0140, is_upper_half=True)
            read_result = sakura.read_internal_data_register()
            self.assertEqual(upper_half, read_result)

        # Verify address read/write
        addr_msb = 0xCD
        append_one = int(False)
        sakura.write_rom_address(addr_msb, append_one)
        output = int(sakura.read(0x0016).hex(), 16)
        # print("Address has the following value: {}".format(output))
        expected_output = (addr_msb << 1) | append_one
        # print("Expected value: {}".format(hex(expected_output)))
        self.assertEqual(output, expected_output)

        addr_msb = 0x00
        append_one = int(True)
        sakura.write_rom_address(addr_msb, append_one)
        output = int(sakura.read(0x0016).hex(), 16)
        # print("Address has the following value: {}".format(output))
        expected_output = (addr_msb << 1) | append_one
        # print("Expected value: {}".format(hex(expected_output)))
        self.assertEqual(output, expected_output)


if __name__ == '__main__':
    unittest.main()
