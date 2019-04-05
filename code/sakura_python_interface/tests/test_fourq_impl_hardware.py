import os
import time
import unittest

from fourq_hardware import fourq_test_vectors, fourq_scalar_mult
from lecroy import lecroy_interface
from lecroy import trace_set_coding
from sakura_g.ftdi_interface import SaseboGii
from utils import files

trace_set_encoder = trace_set_coding.TraceSetCoding()

# TODO make sure to verify how the implementation takes the scalar (either normally or decomposed) value (see constants.vhd).
# TODO change the value accordingly!
takes_decomposed_scalar = True


class TestFourQImplementationHardware(unittest.TestCase):

    def fourq_write_secrets(self, sakura: SaseboGii, test_without_cfk: bool = True, capture_traces=False):
        """
        Write the secret multiscalar and the base point to the corresponding addresses.
        Depending on whether we tests with or without Co-factor killing, we verify the result of the computation with
        with the precomputed tables.
        :param capture_traces: Whether we perform trace acquisition or not
        :param sakura: The FPGA interface
        :param test_without_cfk: whether testing is done with or without co-factor killing
        :return:
        """
        addresses = [
            # The secret multiscalar
            0x00,  # k0 / k1
            0x01,  # k2 / k3
            # Base point
            0x02,  # x0
            0x03,  # x1
            0x04,  # y0
            0x05  # y1
        ]
        if test_without_cfk and takes_decomposed_scalar:
            keys = fourq_test_vectors.keys_decomp
        elif test_without_cfk and not takes_decomposed_scalar:
            keys = fourq_test_vectors.keys
        elif not test_without_cfk:
            keys = fourq_test_vectors.keys_cf
        x_coords = fourq_test_vectors.b_xcoords if test_without_cfk else fourq_test_vectors.b_xcoords_cf
        y_coords = fourq_test_vectors.b_ycoords if test_without_cfk else fourq_test_vectors.b_ycoords_cf

        print("[*] Start computation")
        with lecroy_interface.Lecroy() as lecroy_if:  # type: lecroy_interface.Lecroy
            # lecroy_if.save_panel_to_file("new_cfg_lecroy_trigger_at_start_of_iteration_C3_trigg_C2_power.dat")
            for i in range(9):
                print("[*] Iteration {}/8".format(i))
                for ctr in range(0, len(addresses), 2):
                    # The CFK tests case is exactly the same, but only uses another table
                    table = None
                    if ctr == 0:
                        table = keys
                    elif ctr == 2:
                        table = x_coords
                    elif ctr == 4:
                        table = y_coords

                    cur_addr = addresses[ctr]
                    next_addr = addresses[ctr + 1]
                    sakura.write64(table[4 * i], cur_addr, 0x0140, is_upper_half=False)
                    sakura.write64(table[4 * i + 1], cur_addr, 0x0140, is_upper_half=True)
                    sakura.write64(table[4 * i + 2], next_addr, 0x0140, is_upper_half=False)
                    sakura.write64(table[4 * i + 3], next_addr, 0x0140, is_upper_half=True)

                # Wait for 5 periods
                time.sleep(1)

                # Prepare for capture
                # lecroy_if.prepare_for_trace_capture()

                # Initialize
                sakura.write_operation(0x00, 0x01)
                print("[*] Wait busy done [1/2]")
                # Wait until busy is done
                while sakura.is_busy():
                    continue
                if not test_without_cfk:
                    # Cofactor killing
                    sakura.write_operation(0x00, 0x06)
                    while sakura.is_busy():
                        continue
                # Precomputation + Scalar multiplication + Affine
                sakura.write_operation(0x00, 0x02)
                print("[*] Wait busy done [2/2]")
                while sakura.is_busy():
                    continue

                self.fourq_read_result_point(sakura, i, test_without_cfk)

                if capture_traces:
                    # Acquire trace, Channel 1 is the trigger and Channel 2 is the FPGA power consumption
                    """
                    Three cables:
                    - Trigger to external (or C1) (which is destination J4)
                    - FPGA acq. to C2 and C3

                    Two cables:
                    - Trigger to C3
                    - Acq. to C2 
                    """
                    channel = "C2"
                    channel_out_interpreted = lecroy_if.acquire_trace(channel)
                    # Store in *.tsc format (Format specified by Inspector, see Appendix K of the Inspector manual)
                    trs_file_content = trace_set_encoder.to_trs_format([channel_out_interpreted], [], ["Hoi"],
                                                                       len(channel_out_interpreted),
                                                                       0,  # integer format
                                                                       1  # Sample length in bytes
                                                                       )
                    # Store trace to file and/or plot
                    as_type = "byte"
                    file_name = "wave_form_{}_iteration_{}".format(as_type, i)

                    lecroy_if.save_waveform_data("C2", file_name, as_type=as_type)
                    lecroy_if.plot_waveform(file_name, "plots_{}".format(as_type))

                    dir = "inspector_traces"
                    extension = ".tsc"
                    rel_path = files.join(dir, file_name + extension)
                    abs_path = os.path.abspath(rel_path)
                    os.makedirs(os.path.dirname(abs_path), exist_ok=True)
                    with open(abs_path, "wb+") as f:
                        f.write(trs_file_content)

    def fourq_read_result_point(self, sakura: SaseboGii, iteration: int, test_without_cfk: bool = True):
        """
        Read the result points and verify that they are correct.
        :param sakura: The FPGA interface
        :param iteration: The iteration
        :param test_without_cfk: Whether we tests with or without Cofactor killing
        """
        x_coords = fourq_test_vectors.r_xcoords if test_without_cfk else fourq_test_vectors.r_xcoords_cf
        y_coords = fourq_test_vectors.r_ycoords if test_without_cfk else fourq_test_vectors.r_ycoords_cf
        # Read the result point and compare

        sakura.write_rom_address(0x02, 0x00)  # X0(0)
        data_out = sakura.read_result()
        # print(data_out)
        if data_out != x_coords[4 * iteration]:
            print("Incorrect x-coord[0,0]!")

        sakura.write_rom_address(0x02, 0x01)  # X0(1)
        data_out = sakura.read_result()
        # print(data_out)
        if data_out != x_coords[4 * iteration + 1]:
            print("Incorrect x-coord[0,1]!")

        sakura.write_rom_address(0x03, 0x00)  # X1(0)
        data_out = sakura.read_result()
        # print(data_out)
        if data_out != x_coords[4 * iteration + 2]:
            print("Incorrect x-coord[1,0]!")

        sakura.write_rom_address(0x03, 0x01)  # X1(1)
        data_out = sakura.read_result()
        # print(data_out)
        if data_out != x_coords[4 * iteration + 3]:
            print("Incorrect x-coord[1,1]!")

        sakura.write_rom_address(0x04, 0x00)  # Y0(0)
        data_out = sakura.read_result()
        # print(data_out)
        if data_out != y_coords[4 * iteration]:
            print("Incorrect y-coord[0,0]!")

        sakura.write_rom_address(0x04, 0x01)  # Y0(1)
        data_out = sakura.read_result()
        # print(data_out)
        if data_out != y_coords[4 * iteration + 1]:
            print("Incorrect y-coord[0,1]!")

        sakura.write_rom_address(0x05, 0x00)  # Y1(0)
        data_out = sakura.read_result()
        # print(data_out)
        if data_out != y_coords[4 * iteration + 2]:
            print("Incorrect y-coord[1,0]!")

        sakura.write_rom_address(0x05, 0x01)  # Y1(1)
        data_out = sakura.read_result()
        # print(data_out)
        if data_out != y_coords[4 * iteration + 3]:
            print("Incorrect y-coord[1,1]!")

        sakura.write_rom_address(0x00, 0x00)

        # wait for at least 10 clock cycles
        time.sleep(1)

    def test_fourq_impl(self):
        sakura = SaseboGii()
        # Perform the actual scalar multiplication using FourQ
        fourq_scalar_mult.fourq_initialize_rom(sakura)
        self.fourq_write_secrets(sakura, capture_traces=False)
        sakura.disconnect()
