import unittest
from pathlib import Path
from lecroy.lecroy_interface import *

import numpy as np

lecroy_if = None  # type: Lecroy


class TestLeCroyInterface(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        global lecroy_if
        lecroy_if = Lecroy()

    @classmethod
    def tearDownClass(cls):
        lecroy_if.disconnect()

    def test_get_waveform_template(self):
        waveform_template = lecroy_if.get_waveform_template()
        sub_string = "Explanation of the formats of waveforms"
        self.assertTrue(sub_string in waveform_template)

    def test_get_wavedesc_info(self):
        result = lecroy_if.get_wavedesc_info("C2")
        self.assertTrue("COMM_TYPE" in result)

    def test_get_waveform_description(self):
        waveform_description = lecroy_if.get_waveform_description("C1", use_word_data_format=False)
        self.assertTrue("COMM_TYPE" in waveform_description)

    def test_get_hardcopy(self):
        current_working_directory = os.getcwd()
        filename = "hardcopy_test_file"
        valid_devices = {"BMP", "JPEG", "PNG", "TIFF"}
        valid_formats = {"PORTRAIT", "LANDSCAPE"}
        valid_backgrounds = {"BLACK", "WHITE"}
        valid_areas = {"GRIDAREAONLY", "DSOWINDOW", "FULLSCREEN"}

        for device in valid_devices:
            for format in valid_formats:
                for background in valid_backgrounds:
                    for area in valid_areas:
                        file_path = os.path.join(current_working_directory, filename + "." + device)
                        auxillary = "FORMAT," + format
                        auxillary += ",BCKG," + background
                        auxillary += ",AREA," + area
                        lecroy_if.store_hardcopy_to_file(device, file_path, auxillary)
                        # check if file is created
                        self.assertTrue(Path(file_path).is_file())
                        # Remove the file
                        os.remove(file_path)

    def test_get_signal_bytes(self):
        # First load the configuration
        lecroy_if.load_lecroy_cfg(load_configuration=True)
        # Perform the tests
        for use_word_data_format in [True, False]:
            received_buffer, interpreted_format = lecroy_if.get_native_signal_bytes("C2", np.iinfo(np.int32).max,
                                                                                    use_word_data_format=use_word_data_format)
            first_element_interpreted = interpreted_format[0]
            if use_word_data_format:
                self.assertEqual(first_element_interpreted.nbytes, 2)
            else:
                self.assertEqual(first_element_interpreted.nbytes, 1)

    def test_get_native_signal_float(self):
        # First load the configuration
        lecroy_if.load_lecroy_cfg(load_configuration=True)
        for time_axis in [True, False]:
            received_buffer, interpreted_format = lecroy_if.get_native_signal_float("C2",
                                                                                    np.iinfo(np.int32).max,
                                                                                    time_axis=time_axis)
            if time_axis:
                raw_time_values = interpreted_format[0]
                raw_amplitude_values = interpreted_format[1]
                self.assertEqual(len(raw_amplitude_values), len(raw_time_values))
            else:
                self.assertIsNotNone(interpreted_format)

    def test_get_raw_signal(self):
        # First load the configuration
        lecroy_if.load_lecroy_cfg(load_configuration=True)
        received_buffer, interpreted_format = lecroy_if.get_native_signal_float("C2", np.iinfo(np.int32).max)
        todo = 1

    def test_mmap(self):
        import numpy
        import os
        # See mode on what to do on first use and such...
        from pathlib import Path
        # First create a new file that will function as the memmap
        file_name = "memmap.dat"
        fp = numpy.lib.format.open_memmap(file_name, dtype=np.uint8, mode="w+", shape=(2, 6000))
        fp[0] = np.ones(6000)
        print(fp[0])
        del fp
