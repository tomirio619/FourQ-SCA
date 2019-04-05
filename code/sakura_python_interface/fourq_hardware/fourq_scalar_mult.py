from fourq_hardware import fourq_rom_constants
from sakura_g.ftdi_interface import SaseboGii


def fourq_write_scalar(sakura: SaseboGii, k0 : str, k1: str, k2 : str, k3 : str):
    """
    Write the given scalar to the FPGA. This could either be a decomposed scalar or a normal scalar
    :param sakura:
    :param k0:
    :param k1:
    :param k2:
    :param k3:
    :return:
    """
    addresses = [
        # The secret multiscalar
        0x00,  # k0 / k1
        0x01,  # k2 / k3
    ]

    cur_addr = addresses[0]
    next_addr = addresses[1]
    sakura.write64(k0, cur_addr, 0x0140, is_upper_half=False)
    sakura.write64(k1, cur_addr, 0x0140, is_upper_half=True)
    sakura.write64(k2, next_addr, 0x0140, is_upper_half=False)
    sakura.write64(k3, next_addr, 0x0140, is_upper_half=True)


def fourq_write_base_point(sakura: SaseboGii, x0, x1, y0, y1):
    addresses = [
        # Base point
        0x02,  # x0
        0x03,  # x1
        0x04,  # y0
        0x05  # y1
    ]
    # Mask to select only 64 bits
    mask = 0xFFFFFFFFFFFFFFFF

    x00, x01 = hex(x0 & mask)[2:].zfill(16), hex((x0 >> 64) & mask)[2:].zfill(16)
    x10, x11 = hex(x1 & mask)[2:].zfill(16), hex((x1 >> 64) & mask)[2:].zfill(16)
    y00, y01 = hex(y0 & mask)[2:].zfill(16), hex((y0 >> 64) & mask)[2:].zfill(16)
    y10, y11 = hex(y1 & mask)[2:].zfill(16), hex((y1 >> 64) & mask)[2:].zfill(16)

    sakura.write64(x00, 0x02, 0x0140, is_upper_half=False)
    sakura.write64(x01, 0x02, 0x0140, is_upper_half=True)
    sakura.write64(x10, 0x03, 0x0140, is_upper_half=False)
    sakura.write64(x11, 0x03, 0x0140, is_upper_half=True)
    sakura.write64(y00, 0x04, 0x0140, is_upper_half=False)
    sakura.write64(y01, 0x04, 0x0140, is_upper_half=True)
    sakura.write64(y10, 0x05, 0x0140, is_upper_half=False)
    sakura.write64(y11, 0x05, 0x0140, is_upper_half=True)


def fourq_read_result_point(sakura: SaseboGii):
    addresses = [
        # Base point
        0x02,  # x0
        0x03,  # x1
        0x04,  # y0
        0x05  # y1
    ]
    data_read = []
    for address in addresses:
        sakura.write_rom_address(address, 0x00)  # Xi[0]
        data_out = sakura.read_result()
        data_read.append(data_out)

        sakura.write_rom_address(address, 0x01)  # Xi[1]
        data_out = sakura.read_result()
        data_read.append(data_out)

    x00, x01, x10, x11, y00, y01, y10, y11 = [int(el, 16) for el in data_read]
    x = (int(x01 << 64 | x00), int(x11 << 64 | x10))
    y = (int(y01 << 64 | y00), int(y11 << 64 | y10))
    return x, y


def fourq_initialize_rom(sakura: SaseboGii):
    """
    Initialize the ROM values
    :param sakura: The FPGA interface
    """

    print("[*] Initializing ROM")
    for value in fourq_rom_constants.rom_values:
        lower_half = value[0]
        upper_half = value[1]
        addr = value[2]
        sakura.write64(lower_half, addr, 0x0140, is_upper_half=False)
        sakura.write64(upper_half, addr, 0x0140, is_upper_half=True)
    print("[*] done")
