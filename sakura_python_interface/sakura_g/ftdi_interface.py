from binascii import hexlify, unhexlify
from utils.classes import Singleton


class SaseboGii(metaclass=Singleton):

    def __init__(self):
        result = self._init()
        if result == -1:
            raise Exception("[*] Failed to connected to control FTDI")

    def _print_ftdi_devices(self):
        """

        :return:
        """
        import ftd2xx as ft
        ftdi_devices = ft.listDevices()
        print("[*] Found the following FTDI device(s)")
        devnum = 0
        for ftdi_device in ftdi_devices:
            print("FTDI device:\t {} \t {}".format(ftdi_device, ft.getDeviceInfoDetail(devnum=devnum)))
            devnum += 1

    def _determine_control_fpga(self, ftdi_devices):
        """

        :param ftdi_devices:
        :return:
        """
        for ftdi_device in ftdi_devices:
            if ftdi_device.decode("utf-8")[-1] == 'A':
                return ftdi_device
        print("[*] Unable to determine the SAKURA-G Control FTDI")

    def _connect_to_control_fpga(self, control_fpga):
        result = self._connect(control_fpga)
        print("[*] Connection to Sakura G, FPGA:", control_fpga, "Result:", result)
        return result

    def _init(self):
        """

        :param sakura:
        :type SASEBOGII
        :return:
        """
        import ftd2xx as ft
        print("[*] Sakura SETUP")
        # List FTDI devices
        if ft.listDevices() is None:
            print("[*] Unable to find any FTDI devices")
            return -1
        self._print_ftdi_devices()
        # Select the control FPGA ("A", the control FPGA)
        control_fpga = self._determine_control_fpga(ft.listDevices())
        result = self._connect_to_control_fpga(control_fpga)
        if not result:
            return -1

    def _connect(self, serial_no: object):
        """

        :param serial_no:
        :return:
        """
        import ftd2xx as ft
        # connect to port
        try:
            self.sasebo = ft.openEx(serial_no)  # type: ft.FTD2XX
        except ft.ftd2xx.DeviceError:
            self.sasebo = None
            return False

        self.sasebo.setTimeouts(20000, 20000)
        return True

    def disconnect(self):
        return

    def flush(self):
        """
        Read any bytes that are still waiting to be read
        """
        num = self.sasebo.getQueueStatus()
        if num > 0:
            self.sasebo.read(num)

    def write(self, address: int, msb: int, lsb: int):
        """
        Write at the the address (16 bits) (which the main FPGA uses to write to specific internal signals) the MSB and
        LSB
        :param address: The address (main FPGA specific)
        :param msb: The MSB of the data
        :param lsb: The LSB of the data
        :return:
        """
        msg = bytearray(5)
        msg[0] = 0x02  # Enable writing
        msg[1] = (address >> 8) & 0xFF  # MSB address
        msg[2] = address & 0xFF  # LSB address
        msg[3] = msb  # MSB data
        msg[4] = lsb  # LSB data
        msg = bytes(msg)
        self.sasebo.write(msg)

    def read(self, address: int) -> bytearray:
        """
        Read from the address (which is specific to the main FPGA)
        :param address: The address (4 byte hex)
        :type: int
        :return:
        """
        self.flush()
        msg = bytearray(3)
        msg[0] = 0x01  # Enable reading
        msg[1] = (address >> 8) & 0xFF  # MSB address
        msg[2] = address & 0xFF  # LSB address
        msg = bytes(msg)
        self.sasebo.write(msg)
        msg = self.sasebo.read(2)  # Read two bytes
        msg = bytearray(msg)
        return msg

    def read64(self, address: int) -> bytearray:
        """
        Read 64 bits from the main FPGA starting from the given address
        :param address: The internal address (main FPGA specific)
        :return: The bytes read from the FPGA starting from the specified address
        """
        response_msg = bytearray(8)
        for i in range(4):
            # Write address to read from
            addr_msb = (address >> 8) & 0xFF
            addr_lsb = (address & 0xFF) + (i * 2)
            addr = (addr_msb << 8) | addr_lsb
            # Read bytes at the address
            bytes_read = self.read(addr)
            # Store results at correct position
            response_msg[i * 2] = bytes_read[0]
            response_msg[i * 2 + 1] = bytes_read[1]
        return response_msg

    def close(self):
        """
        Close connection with the FPGA
        """
        self.sasebo.close()

    def write64(self, rom_value_64bits: str, rom_address: int, main_fpga_internal_address: int,
                is_upper_half: bool, data_enable: bool = True):
        """
        Write a 64-bit value into the register of the main FPGA. In addition, we also write a ROM address into the
        corresponding register. This will be the address at which this 64-bit value will be stored (FourQ specific)
        :param data_enable: Whether we want to enable the data (such that it becomes written to the RAM)
        :param rom_value_64bits:  The HEX value to write into the register
        :param rom_address:  The ROM address
        :param main_fpga_internal_address: The internal addresses which determine which bits of the register get written
        :param is_upper_half: Whether te 64 bits value to write is the lower or upper half of the whole message.
        :param data_enable: Whether the write enable within the FourQ design should be enabled
        """
        # Return the binary data represented by the hexadecimal string
        hex_bytes = bytearray(unhexlify(rom_value_64bits))
        hex_bytes = hex_bytes.decode("latin-1")
        # ord() returns the value of the byte when the argument is an 8-bit string
        hex_bytes_values = list(map(ord, hex_bytes))
        for i in range(0, len(hex_bytes_values), 2):
            # print(hex(main_fpga_internal_address + i))
            self.write(main_fpga_internal_address + i, hex_bytes_values[i], hex_bytes_values[i + 1])

        # Write the corresponding address at which this value has to be loaded in RAM
        msb = rom_address
        lsb = 0x01 if is_upper_half else 0x00
        self.write_rom_address(msb, lsb)
        if data_enable:
            self.set_data_valid()

    def is_busy(self) -> bool:
        """
        Indicates whether the algorithm running on the FPGA is busy or not
        :return: True if the busy flag is high, False otherwise
        """
        output = hexlify(self.read(0x0001))
        output = int(output, 16)
        # print(output)
        # Busy signal is the third bit
        busy = (output >> 2) & 1

        return bool(busy)

    def read_internal_data_register(self) -> str:
        """
        Read the internal data register (64 bits)
        :return: The data in the internal data register
        """
        return self.read64(0x0296).hex()

    def read_result(self) -> str:
        """
        Read the result (i.e output) of the internal design
        :return: The output of the design, as a HEX string
        """
        return self.read64(0x0186).hex()

    def write_operation(self, msb: int, lsb: int):
        """
        Write the operation
        :param msb: The MSB
        :param lsb: the LSB
        """
        self.write(0x0136, msb, lsb)

    def write_rom_address(self, msb: int, lsb: int):
        """
        Write the ROM address
        :param msb: the MSB
        :param lsb: the LSB
        """
        self.write(0x0138, msb, lsb)

    def set_data_valid(self):
        """
        Set the data valid (i.e. set Write Enable high) in the design
        """
        self.write(0x0002, 0x00, 0x02)
