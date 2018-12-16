import errno
import os
import struct
import time

import matplotlib.pyplot as plt
import numpy as np
import win32com.client  # import the pywin32 library

from utils import files
from utils.classes import Singleton


class Lecroy(metaclass=Singleton):
    """
    This class interfaces the Teledyne LeCroy oscilloscopes, more specifically the Teledyne LeCroy - WaveRunner 610Zi.
    Although different methods can be used  to interface with the oscilloscope, we make use of the method in which
    the Enternet interface is used.
    Teledyne LeCroy oscilloscopes employ a standard Ethernet interface for utilizing the TCP/IP transport layer.
    Each oscilloscope is delivered with a default IP address, which is pulled from our network prior to shipment.
    This address can be found by navigating to Utilities > Utilities Setup > Remote, where it can also be changed
    This address is used to connect to the oscilloscope.

    One of the ways to manage Remote control of the oscilloscope is by making use of
    Microsoft's ActiveX technology ActiveDSO.
    This standard makes us able to control the oscilloscope and to exchange data with it by making use of other Windows
    applications that support this ActiveX standard. The control's external name is always: 'LeCroy.ActiveDSOCtrl.1'.

    In python, instantiation of the control as an "invisible" object to pass remote commands to  is done as follows:
    <code>
    import win32com.client
    dso=win32com.client.Dispatch("LeCroy.ActiveDSOCtrl.1")
    </code>

    To actually connect a connection from this control object to the oscilloscope, we make use of the `MakeConnection'
    method. This method requires the address of the interface of the oscilloscope to which you want to connect.
    The code looks as follows:
    <code>
    MakeConnection("IP: 172.25.9.22")
    </code>

    Now we have established a connection to the oscilloscope, its time to send commands to the connected device.
    Commands are send using the following syntax:
    <code>
    <controlName>.WriteString("<textString>", <EOI Boolean>)
    <controlName>:= name used to instantiate the ActiveDSO control
    <textString>:= command string sent to the device
    <EOI Boolean>:= {1, 0}
    </code>
    If EOI is set to 1 (TRUE), the command terminates with EOI, and the device interprets the command right
    away. This is normally the desired behavior.
    If EOI is set to 0 (FALSE), a command may be sent in several parts with the device starting to interpret the
    command only when it receives the final part, which should have EOI set to TRUE.

    To read the response from the instrument for a given command, we make use of the 'ReadString' method.
    Its only argument is the number of bytes to read:
    <code>
    <controlName>.ReadString(<bytesToRead>, <EOI Boolean>)
    <bytesToRead>:= number of bytes to read
    </code>

    Example code of interfacing the oscilloscope using the ActiveDSO technology can be seen in on page 2-51 of the
    "MAUI Oscilloscopes Remote Control and Automation Manual".
    The automation programming conventions can be read in the section "Automation Programming Conventions" of the manual
    "MAUI Oscilloscopes Remote Control and Automation Manual".

    VBS
    The VBS command allows Automation commands to be sent in the context of an existing program.
    The Automation command must be placed within single quotation marks.
    The equal sign (=) within the automation command may be flanked by optional spaces for clarity.

    * Query syntax:
    <code>
        VBS? 'Return=<automation command>'
    </code>

    There are two types of commands that can be send to the oscilloscope. We have GPIB remote control commands and VBS
    commands (page 210).
    General Purpose Interface Bus (GPIB) for remote control of oscilloscopes from a PC or other controller device is
    only partly implemented by Teledyne LeCroy.
    We refer to the Remote Control Manual for more details on GPIB and VBS commands.
    """

    def __init__(self, ip_address="192.168.0.1"):
        """
        Create the control object that will be used to 'talk' to the oscilloscope
        """
        command = "LeCroy.ActiveDSOCtrl.1"
        self._scope = win32com.client.Dispatch(command)
        self.ip_address = ip_address
        self.connect()
        # Intel systems us least-significant byte order
        self.set_communication_order(use_big_endian=False)

    def __enter__(self):
        return self

    def __del__(self):
        """
        Disconnect from the oscilloscope
        """
        self.disconnect()

    def __exit__(self, exc_type, exc_val, exc_tb):
        """
        Disconnect from the oscilloscope
        """
        self.disconnect()

    def connect(self):
        """
        Connect to the oscilloscope using the IP address (this IP address should match the one in the settings of
        the oscilloscope
        """
        command = "IP:" + self.ip_address
        self._scope.MakeConnection(command)
        # The *IDN? query causes the instrument to identify itself. The response comprises manufacturer,
        # oscilloscope model, serial number, and firmware revision level.
        command = "*IDN?"
        self._scope.WriteString(command, True)
        response = self._scope.ReadString(80)
        print("[!] Connected scope: {}".format(response))
        if response is None or "LECROY" not in response:
            raise Exception("Something went wrong while connecting to the Teldyne LeCroy Oscilloscope")

    def set_acquisition_sampling_rate(self, rate: int):
        """
        Set the sampling rate.
        Mega = 10e6
        Giga = 10e9
        :param rate: The acquisition rate
        """
        command = 'vbs app.Acquisition.Horizontal.SampleRate = {}'.format(rate)
        self._scope.WriteString(command, True)

    def get_acquisition_sampling_rate(self):
        """
        Get the sampling rate
        :return: The current sampling rate used for acquisitions
        """
        command = 'vbs? Return=app.Acquisition.Horizontal.SampleRate'
        self._scope.WriteString(command, True)
        response = int(self._scope.ReadString(80))
        return response

    def get_horizontal_offset(self):
        command = 'vbs? Return=app.Acquisition.Horizontal.HorOffset'
        self._scope.WriteString(command, True)
        response = float(self._scope.ReadString(80))
        return response

    def set_horizontal_offset(self, offset: float):
        command = 'vbs app.Acquisition.Horizontal.HorOffset = {}'.format(offset)
        self._scope.WriteString(command, True)

    def get_volts_div(self, channel):
        """
        Get the volts division of one of the channels
        :param channel: String with the name of the channel, can be: "C1", "C2", "C3", "C4",...
        :return: The volts division for the specified channel
        """
        command = str(channel) + ":VDIV?"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(80)

    def set_volts_div(self, channel, volts_per_division):
        """
        Change the volts division of one of the channels
        :param channel: String with the name of the channel, can be:  "C1", "C2", "C3", "C4", ...
        :param volts_per_division: Number of Volts per Division, like "1.0" for 1.0 Volts per division or "0.02" for 20
        mV of division
        """
        command = "{}:VDIV {}".format(channel, volts_per_division)
        self._scope.WriteString(command, True)

    def get_volts_offset(self, channel):
        """
        Get vertical offset of the specified input channel
        :param channel: String with the name of the channel, can be:  "C1", "C2", "C3", "C4", ...
        :return: The offset in Volts
        """
        command = str(channel) + ":" + "OFST?"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(80)

    def set_volts_offset(self, channel, volts_offset):
        """
        Setthe vertical offset of the specified input channel
        :param channel: String with the name of the channel, can be:  "C1", "C2", "C3", "C4", ...
        :param volts_offset: The vertical offset as an integer
        """
        command = str(channel) + ":" + "OFST " + volts_offset
        self._scope.WriteString(command, True)

    def get_time_div(self) -> str:
        """
        Returns the current timebase setting.
        :return: The current timebase setting.
        """
        command = "TDIV?"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(80)

    def set_time_div(self, time_div: str):
        """
        The TIME_DIV command modifies the timebase setting. The timebase setting can be specified with units:
        NS for nanoseconds, US for microseconds, MS for milliseconds, S for seconds, or KS for kiloseconds.
        Alternatively, you can use exponential notation: 10E-6, for example. An out-of-range value causes the VAB
        bit (bit 2) in the STB register to be set.
        :param time_div: The new timebase setting
        """
        command = "TDIV " + time_div
        self._scope.WriteString(command, True)

    def get_trigger_delay(self) -> str:
        """
        :return: The trigger time with respect to the first acquired data point.
        The <value> is given in time and may be anywhere in the ranges:
        Negative delay: ( 0 to -10,000) * Time/div
        Positive delay: (0 to +10) * Time/div
        If the value is negative it will be in seconds format ( After the trigger event )
        If the value is positive it will be a percentage format ( Before the trigger event )
        """
        command = "TRDL?"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(80)

    def set_trigger_delay(self, trigger_delay: str):
        """
        Sets the time at which the trigger is to occur with respect to the nominal zero delay position, which defaults
        to the center of the grid. This is also referred to as Horizontal Delay.
        :param trigger_delay:
        """
        command = "TRDL " + trigger_delay
        self._scope.WriteString(command, True)

    def get_trigger_level(self, channel) -> str:
        """
        Returns the current trigger level for the specified channel.
        :param channel:
        :type channel: str
        :return: the amount of Volts
        :rtype: str
        """
        command = channel + ":" + "TRLV?"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(80)

    def set_trigger_level(self, channel: str, trigger_level: str):
        """
        Set the trigger level for a specified channel.
        :param channel: String with the name of the channel, can be:  "C1", "C2", "C3", "C4", "EX" or "EX10"
        :type channel: str
        :param trigger_level: The new trigger level of the specified trigger source
        :type trigger_level: str
        """
        command = channel + ":" + "TRLV " + trigger_level
        self._scope.WriteString(command, True)

    def get_trigger_mode(self) -> str:
        """
        Returns the current trigger mode.
        :return: "AUTO", "NORM", "SINGLE" or "STOP"
        :rtype: str
        """
        command = "TRMD?"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(80)

    def set_trigger_mode(self, trigger_mode: str):
        """
        Set the trigger mode
        :param trigger_mode: The new trigger mode, which could be: "AUTO", "NORM", "SINGLE" or "STOP"
        :type trigger_mode: str
        """
        command = "TRMD " + trigger_mode
        self._scope.WriteString(command, True)

    def get_trigger_slope(self, channel: str) -> str:
        """
        Returns the trigger slope of the selected source.
        :param channel: String with the name of the channel, can be: "C1", "C2", "C3", "C4", "EX" or "EX10"
        :type channel: str
        :return: String of the current slope, which could be "NEG" or "POS"
        :rtype: str
        """
        command = str(channel) + ":" + "TRSL?"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(80)

    def set_trigger_slope(self, channel: str, trigger_slope: str):
        """

        :param channel:
        :type channel: String with the name of the channel, can be: "C1", "C2", "C3", "C4", "EX" or "EX10"
        :param trigger_slope: String of the current slope, which could be "NEG" or "POS"
        :type trigger_slope: str
        """
        command = str(channel) + ":" + "TRSL " + trigger_slope
        self._scope.WriteString(command, True)

    def get_panel(self) -> str:
        """
        The GetPanel method reads the instrument's control state into a String, allowing a future call to SetPanel to
        reproduce the state.
        :return: A string containing the hex-ascii Panel. The size of the panel will be approximately 5000 bytes,
        depending upon the instrument's firmware revision.
        :rtype: str
        """
        panel = self._scope.GetPanel()
        return panel

    def set_panel(self, panel):
        """
        The SetPanel method sets the instrument's control state using a panel string captured using the method GetPanel.
        :param panel: A string containing the hex-ascii Panel
        :type panel: str
        """
        self._scope.SetPanel(panel)

    def arm_and_wait_lecroy(self):
        """
        ARM starts a new data acquisition. The WAIT command prevents your instrument from analyzing new commands until
        the current acquisition has been completed.
        """
        command = "ARM; WAIT"
        self._scope.WriteString(command, True)

    def stop_lecroy(self):
        """
        Immediately stops signal acquisition.
        """
        command = "STOP"
        self._scope.WriteString(command, True)

    def enable_wait_lecroy_acquisition(self, timeout=1):
        """
        The WAIT command prevents your instrument from analyzing new commands until
        the current acquisition has been completed.
        :return:
        :rtype:
        """
        command = "WAIT {}".format(timeout)
        self._scope.WriteString(command, True)

    def disconnect(self):
        """
        Disconnect from the oscilloscope
        """
        self._scope.Disconnect()

    def load_panel_from_file(self, panel_file_name: str):
        """
        Load a panel stored in a file to the LeCroy.
        This panel should be obtained using the GetPanel method, and is loaded using the SetPanel method
        :param panel_file_name: The file name of the file that holds the panel to be loaded
        :type panel_file_name: str
        """
        with open(panel_file_name, "rt") as file:
            panel = file.read()
            buffer = file.read()
            if buffer != '':
                panel += buffer
            if panel != "":
                self._scope.SetPanel(panel)

    def save_panel_to_file(self, panel_file_name: str):
        """
        Save a panel obtained from the LeCroy to a file.
        :param panel_file_name: The file name of the file that will contain the saved panel.
        :type panel_file_name: str
        """
        panel = self._scope.GetPanel()
        dir = "lecroy_cfgs"
        panel_file_name = files.get_full_path(dir, panel_file_name)
        with open(panel_file_name, "wt") as file:
            file.write(panel)

    def get_waveform_template(self) -> str:
        """
        This gives a detailed description of the form and content of the logical data blocks of a waveform, and is
        provided as a reference. It is suggested that the TEMPLATE? query and the actual instrument template is used
        instead of exampled provided in the manual. The template may change as the instrument’s firmware is enhanced,
        and it will help provide backward compatibility for the interpretation of waveforms
        :return: The waveform template
        :rtype:
        """
        command = "TMPL?"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(np.iinfo(np.int32).max)

    def store_hardcopy_to_file(self, format, filename, aux_format=""):
        """

        :param format: The hardcopy format (see hardcopy setup for possible formats)
        :param aux_format: Used to send extra information to the HARDCOPY_SETUP command.
        This could include the paper orientation (" FORMAT,PORTRAIT ", or " FORMAT,LANDSCAPE "),
        page-feed (" PFEED,ON "or " PFEED,OFF "), etc. Again, see the HARDCOPY_SETUP page of the instrument remote
        control manual for more details.
        :param filename: The filename
        :return:
        """
        self._scope.StoreHardcopyToFile(format, aux_format, filename)

    def get_hardcopy_settings(self) -> str:
        """
        The HARDCOPY_SETUP query returns the oscilloscope's current print settings.
        :return: The current print settings for the oscilloscope
        :rtype: str
        """
        command = "HCSU?"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(5000)

    def set_hardcopy_settings(self, device: str = "TIFF", format: str = "PORTRAIT", bckg: str = "WHITE",
                              destination: str = "FILE",
                              directory="my_directory", hardcopy_area="FULLSCREEN", filename="my_hardcopy",
                              printer_name=None, port_name="NET"):
        """
        The HARDCOPY_SETUP command specifies the device type and transmission mode of the instrument's
        print driver. This can be the instrument clipboard, hard drive or email, as well as a printer.
        One or more individual settings can be changed by specifying the appropriate keywords, together with the
        new values. If you send contradictory values within a command, the result is governed by the last one
        sent.
        :param directory: legal DOS path, for FILE mode only
        :type directory: str
        :param hardcopy_area: {GRIDAREAONLY, DSOWINDOW, FULLSCREEN}
        :type hardcopy_area: str
        :param device: {BMP, JPEG, PNG, TIFF}
        :type device: str
        :param format: {PORTRAIT, LANDSCAPE}
        :type format: str
        :param bckg: {BLACK, WHITE}
        :type bckg: str
        :param destination: {PRINTER, CLIPBOARD, EMAIL, FILE, REMOTE}
        :type destination: str
        :param filename: filename string, no extension, for FILE mode only
        :type filename: str
        :param printer_name: valid printer name, for PRINTER mode only
        :type printer_name: str
        :param port_name: {GPIB, NET}
        :type port_name: str
        """
        command = "HCSU "
        command += "DEV," + device
        command += ",FORMAT," + format
        command += ",BCKG," + bckg
        command += ",DEST," + destination
        command += ",AREA," + hardcopy_area
        command += ",PORT," + port_name

        if destination == "FILE":
            command += ",FILE," + '"' + filename + '"'
            command += ",DIR," + '"' + directory + '"'
        elif destination == "PRINTER":
            command += ",PRINTER," + '"' + printer_name + '"'
        self._scope.WriteString(command, True)

    def screen_dump(self):
        """
        The SCREEN_DUMP command causes the instrument to send the screen contents to the current
        hardcopy device. The time-and-date stamp corresponds to the time of the command.
        :return:
        :rtype:
        """
        command = "SCDP"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(5000)

    def set_communication_order(self, use_big_endian: bool = True):
        """
        The COMM_ORDER command controls the byte order of waveform data transfers. Waveform data can be
        sent with the most significant byte (MSB) or the least significant byte (LSB) in the first position. The
        default mode is to send the MSB first. COMM_ORDER applies equally to the waveform's descriptor and
        time blocks. In the descriptor some values are 16 bits long (word), 32 bits long (long or float), or 64 bits
        long (double). In the time block all values are floating values, meaning, 32 bits long.
        When COMM_ORDER HI is specified, the MSB is sent first; when COMM_ORDER LO is specified, the LSB is sent first.
        :param use_big_endian: Whether to use MSB or LSB order
        :type use_big_endian: bool
        """
        command = "CORD HI" if use_big_endian else "CORD LO"
        self._scope.WriteString(command, True)

    def get_communication_order(self):
        """
        Get the byte transmission order in current use.
        :return: the byte transmission order: "HI" or "LO" (either big or little endian)
        :rtype: str
        """
        command = "CORD?"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(80)

    def get_waveform_binary(self, channel: str, use_word_data_format: bool = True, use_big_endian: bool = True):
        """
        Get the waveform as binary.
        :param use_big_endian: Whether to use big endian format or not (otherwise little endian will be used)
        :type use_big_endian: bool
        :param channel:
        :type: str
        :param use_word_data_format: Whether to use the byte format (otherwise word format is used)
        :type: bool
        :return:
        """
        # Selects the format for sending waveform data, which is set to block format (DEF9)
        command = "CFMT DEF9,"
        # Determine whether to use the BYTE or WORD data format
        command += ("WORD," if use_word_data_format else "BYTE,")
        # Set the encoding to binary (which is the only option available)
        command += "BIN"
        self._scope.WriteString(command, True)
        """
        Specifies the amount of data in a waveform to be transmitted to the controller. The command syntax is as follows
        
        WAVEFORM_SETUP SP,<sparsing>,NP,<number>,FP,<first point>,SN,<segment>
        * The sparsing parameter defines the interval between data points. A value of 0 and 1 indicates that all points
        should be sent.
        * The number of points parameter indicates how many points should be transmitted. A value of 0 indicates that 
        all data points should be sent
        * The first point parameter specifies the address of the first data point to be sent. A value of 0 corresponds 
        to the first data point, a value of 1 corresponds to the second data point.
        * The segment number parameter indicates which segment should be sent if the waveform was acquired in sequence 
        mode. This parameter is ignored for non-segmented waveforms.
        """
        command = "WFSU SP,0,NP,0,FP,0,SN,0"
        self._scope.WriteString(command, True)
        # Control the byte order of waveform data transfers
        self.set_communication_order(use_big_endian=use_big_endian)
        # The WAVEFORM? query is an effective way to transfer waveform data in block formats defined by the
        # IEEE 488.2 standard. By adding the block name as a parameter ('DAT1' below), we can also query for a single
        # block
        command = channel + ":" + "WF?" + " DAT1"
        self._scope.WriteString(command, True)
        waveform = self._scope.ReadBinary(1000)
        buffer = self._scope.ReadBinary(1000)
        # A WF? query response can easily contain over 16 million bytes if in binary form and twice as much
        # if the HEX option is used.
        while len(buffer) > 0:
            waveform += buffer
            buffer = self._scope.ReadBinary(1000)
        return waveform

    def get_wavedesc_info(self, channel: str) -> str:
        command = channel + ":INSP? 'WAVEDESC'"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(np.iinfo(np.int32).max)

    def get_waveform_description(self, channel: str, use_word_data_format: bool = True) -> dict:
        """
        Get a description of the waveform.
        :param channel: C1 to Cn, F1 to Fn, M1 to Mn, TA to TD
        :type channel: str
        :param use_word_data_format: whether the WORD data type should be used for transmission of the waveform
        data or not. If true the WORD data type is used for transmission, which tells the oscilloscope that the
        waveform data should be transmitted as 16-bit signed  integers (two bytes). If false, the BYTE data type is
        used, in which the waveform is transmitted as 8-bit signed integers.
        NOTE: the data type BYTE transmits only the high-order bits of the internal 16-bit representation.
        The precision contained in the low-order bits is lost.
        :type use_word_data_format: bool
        :return: (voltage_gain, voltage_offset, time_interval, time_offset)
        :rtype: (float, float, float, float)
        """
        # Selects the format for sending waveform data
        if use_word_data_format:
            command = 'CFMT ' + 'DEF9,' + 'WORD,' + 'BIN'
            self._scope.WriteString(command, True)
        else:
            command = 'CFMT ' + 'DEF9,' + 'BYTE,' + 'BIN'
            self._scope.WriteString(command, True)

        # Set COMMAND HEADER to NONE, such that the header is omitted in the response to the query
        self.set_command_header(mode="OFF")

        # Determine which variables are present int the Waveform Descriptor Block of the specified channel.
        # We store them in a dictionary that we will return
        waveform_descriptor_dict = {}
        waveform_descriptor = self.get_wavedesc_info(channel)
        waveform_descriptor = waveform_descriptor.replace('"', '')
        waveform_descriptor_key_value_pairs = waveform_descriptor.split("\r\n")
        for key_value_pair in waveform_descriptor_key_value_pairs:
            if len(key_value_pair) == 0:
                continue
            # split in key and value
            key, value = key_value_pair.split(':', 1)
            # Remove leading and trailing white spaces
            key = key.strip()
            value = value.strip()
            # store in dictionary
            waveform_descriptor_dict[key] = value

        return waveform_descriptor_dict

    def get_command_header(self):
        """
        See the corresponding set function
        :return:
        """
        command = "CHDR?"
        self._scope.WriteString(command, True)
        return self._scope.ReadString(80)

    def set_command_header(self, mode="SHORT"):
        """
        The COMM_HEADER command controls the way the oscilloscope formats responses to queries.
        There are three response formats; unless you request otherwise, the short response format is used.
        This command does not affect the interpretation of messages sent to the oscilloscope, only responses to
        queries. Headers can be sent in longor short form regardless of the COMM_HEADER setting.
        :param mode: The response format ("SHORT", "LONG" or "OFF")
        :return:
        """
        command = "CHDR " + mode
        self._scope.WriteString(command, True)

    def comm_order_is_big_endian(self):
        """
        Indicates whether the current communication order is Big endian or not.
        If not, the communication order for values consisting of multiple bytes is little endian.
        :return: True when the communication order is MSB first, False when the LSB is sent first.
        """
        lecroy_communication_order = self.get_communication_order()
        return True if lecroy_communication_order == "HI" else False

    def get_raw_signal(self, channel, number_of_points=100000000, which_array=0, use_word_data_format=True):
        """
        Get raw data from lecroy on bytes format.
        :param channel: C1 | C2 | C3 | C4 | M1 | M2 | M3 | M4 | TA | TB | TC | TD TD | F1 | Z1 | …
        :type channel: str
        :param number_of_points: Maximum number of bytes to read
        :type number_of_points: int
        :param which_array: Only used to specify that the second array of a dual-array waveform is required. This
        parameter should normally be zero
        :type which_array: int
        :param use_word_data_format: Whether to use the WORD or BYTE data type for waveform transmission.
        :type use_word_data_format: bool
        :return: Either raw 16-bit waveform data as an integer array or a raw 8-bit waveform data as a Byte array.
        An important point to note when using this function is that in order to store the signed data that the scope
        emits (-128 to 127) into Visual-Basic's unsigned 'Byte' data type it has been shifted by 128 (0 to 255).
        This should be remembered when scaling the data.
        :rtype:
        """
        starting_point = 0  # The point to start transfer (0 = first)
        number_of_points_to_jump = 0  # How many points to jump (0 = get all points, 2 = skip every other point)
        segment_number = 0  # Segment number to get, in case of sequence waveforms.
        self._scope.SetupWaveformTransfer(starting_point, number_of_points_to_jump, segment_number)
        if use_word_data_format:
            # The GetIntegerWaveform method reads raw 16-bit waveform data from the instrument into an Integer array.
            return self._scope.GetIntegerWaveform(channel, number_of_points, which_array)
        else:
            # The GetByteWaveform method reads raw 8-bit waveform data from the instrument into a Byte array.
            # An important point to note when using this function is that in order to store the signed data that the
            # scope emits (-128 to 127) into Visual-Basic's unsigned 'Byte' data type it has been shifted by 128
            # (0 to 255). This should be remembered when scaling the data.
            return self._scope.GetByteWaveform(channel, number_of_points, which_array)

    def get_native_signal_bytes(self, trace_name, max_bytes, use_word_data_format=True, block_name="DAT1"):
        """
        Read a waveform from the instrument in its native binary form.
        The difference with this method, is that the waveform has already been preprocessed by lecroy.
        * Channel waveforms (C1..C4) should be transmitted in 8-bit form by setting wordData FALSE.
        * Only complete waveforms transferred with (ALL) can be sent back into the instrument using the
        SetNativeWaveformSetNativeWaveform_Method Method.
        * If chosen to use 16 bits format it is possible to reload Lecroy with the same signal.
        * If chosen the 8 bits format, then it is not possible to load Lecroy with the signal.
        :param trace_name: C1 | C2 | C3 | C4 | M1 | M2 | M3 | M4 | TA | TB | TC | TD TD | F1 | Z1 | …
        :type trace_name: str
        :param max_bytes: Long, maximum number of bytes to read
        :type max_bytes: int
        :param use_word_data_format: if TRUE transmit data as 16 bit words, FALSE for 8 bit words.
        :type use_word_data_format: bool
        :param block_name: used to transfer the descriptor (DESC), the user text (TEXT), the time descriptor (TIME),
        the data (DAT1) block and optionally a second block of data (DAT2) or all entities (ALL).
        :type block_name: str
        :return: (received_buffer, interpreted_format)
        :rtype: (list, list)
        """
        starting_point = 0  # The point to start transfer (0 = first)
        number_of_points_to_jump = 0  # How many points to jump (0 = get all points, 2 = skip every other point)
        segment_number = 0  # Segment number to get, in case of sequence waveforms.
        # Setup transfer
        self._scope.SetupWaveformTransfer(starting_point, number_of_points_to_jump, segment_number)
        data_format = 1 if use_word_data_format else 0
        # Receive waveform
        received_buffer = self._scope.GetNativeWaveform(trace_name, max_bytes, data_format, block_name)
        interpret_as_big_endian = self.comm_order_is_big_endian()
        # Interpret the received buffer as a 1-dimensional array of the appropriate type.
        # See "Data type objects" section in Numpy docs to see what the abbreviations mean.
        # First character specifies the byte order, 'i' specifies the type and 2 specifies the number of bytes
        if use_word_data_format:
            dt = ">i2" if interpret_as_big_endian else "<i2"
            interpreted_format = np.frombuffer(received_buffer, dtype=dt)
        else:
            interpreted_format = np.frombuffer(received_buffer, dtype='i1')
        return received_buffer, interpreted_format

    def set_native_signal_bytes(self, destination, native_waveform):
        """
        This method sends a waveform captured using the GetNativeWaveform method back into the instrument.
        Note that waveforms captured using the other GetxxxWaveform functions cannot be sent back into the instrument
        in this way. Only complete waveforms transferred with (ALL) can be sent back into the instrument using the
        SetNativeWaveformSetNativeWaveform_Method Method.
        :param destination:
        :type destination:
        :param native_waveform: A waveform captured using the GetNativeWaveform in which ALl entities were captured.
        :type native_waveform: bytearray
        """
        self._scope.SetNativeWaveform(destination, native_waveform)

    def get_native_signal_float(self, channel: str, max_bytes: int = 1000000000, which_array: int = 0,
                                time_axis: bool = False):
        """
        Get scaled data from Lecroy in single-precision float format (i.e. 4 bytes for a single float).
        :param channel: C1 | C2 | C3 | C4 | M1 | M2 | M3 | M4 | TA | TB | TC | TD TD | F1 | Z1 | …
        :param max_bytes: maximum number of bytes to read
        :param which_array: Only used to specify that the second array of a dual-array waveform is required. This
        parameter should normally be zero
        :param time_axis: Whether we need to store the time and amplitude at each sample point (i.e. use the
        GetScaledWaveformWithTimes method instead of the GetScaledWaveform method)
        :return:
        """
        starting_point = 0  # The point to start transfer (0 = first)
        number_of_points_to_jump = 0  # How many points to jump (0 = get all points, 2 = skip every other point)
        segment_number = 0  # Segment number to get, in case of sequence waveforms.
        self._scope.SetupWaveformTransfer(starting_point, number_of_points_to_jump, segment_number)
        interpret_as_big_endian = self.comm_order_is_big_endian()
        byte_order = ">" if interpret_as_big_endian else "<"
        if time_axis:
            interpreted_format = self._scope.GetScaledWaveformWithTimes(channel, max_bytes, which_array)
            # Returns: A variant containing the scaled waveform, stored as a two-dimensional array of single-precision
            # floating point values.  Time values are stored in the first column of the array, amplitude values are
            # stored in the second column.
            received_buffer = [0, 0]
            # struct.pack supports variadic arguments, which means that a variable number of arguments can be passed
            # Determine formats strings to use
            time_values = [i[0] for i in interpreted_format]
            amplitude_values = [i[1] for i in interpreted_format]
            # A format character may be preceded by an integral repeat count.
            # For example, the format string '4h' means exactly the same as 'hhhh'.
            time_values_len = str(len(time_values))
            amplitude_values_len = str(len(amplitude_values))
            # Pack the values
            received_buffer[0] = struct.pack(byte_order + time_values_len + "f", *time_values)
            received_buffer[1] = struct.pack(byte_order + amplitude_values_len + "f", *amplitude_values)
        else:
            interpreted_format = self._scope.GetScaledWaveform(channel, max_bytes, which_array)
            # Returns: A variant containing the scaled waveform, stored as an array of single-precision floating point
            # values
            scaled_waveform_len = str(len(interpreted_format))
            received_buffer = struct.pack(byte_order + scaled_waveform_len + 'f', *interpreted_format)
        return received_buffer, interpreted_format

    def set_vertical_offset(self, channel: str, offset: float):
        """
        The OFFSET command allows adjustment of the vertical offset of the specified input channel at the probe tip.
        :param offset: The offsets in Volts (V) (be aware, the oscilloscope shows this value in mV!)
        :param channel: The channel
        :return: The offsets for the given channel.
        """
        # Convert offset to scientific notation
        # offset = '{:.4e}'.format(offset)
        # offset  = '7.0000e-003'
        command = "{}:OFFSET {}".format(channel, offset)
        self._scope.WriteString(command, True)

    def get_vertical_offset(self, channel: str = "C3"):
        command = "{}:OFFSET?".format(channel)
        self._scope.WriteString(command, True)
        vertical_offset = float(self._scope.ReadString(80))
        return vertical_offset

    def set_vertical_division(self, channel: str, sensitivity: float):
        """
        Set the V/div for the given channel
        :param channel: The channel
        :param sensitivity: The sensitivity
        """
        command = "{}:VDIV {}".format(channel, sensitivity)
        self._scope.WriteString(command, True)

    def get_vertical_division(self, channel: str):
        """
        Get the vertical division of a channel.
        :param channel: A channel
        :return: The vertical division of this channel
        """
        command = "{}:VDIV?".format(channel)
        self._scope.WriteString(command, True)
        response = self._scope.ReadString(np.iinfo(np.int_).max)
        return float(response)

    def set_bandwidth_limit(self, channel: str, mode: str):
        """
        The BANDWIDTH_LIMIT command enables or disables the bandwidth-limiting low-passfilter on a per-channel basis.
        When the <channel> argument is omitted, the BWL command applies to all channels.
        :param channel: The channel
        :param mode: {OFF, 20MHZ, 200MHZ}
        """
        command = "BWL {}, {}".format(channel, mode)
        self._scope.WriteString(command, True)

    def get_bandwidth_limit(self):
        """
        Get the bandwidth limit (BWL) for all channels
        :return:
        """
        command = "BWL?"
        self._scope.WriteString(command, True)
        response = self._scope.ReadString(np.iinfo(np.int_).max)
        return response

    def set_memory_size(self, size: int):
        command = "MSIZ"

    def set_transfers_timeout(self, seconds: int = 10):
        """
        Sets the control’s time-out time
        :param seconds: Time-out time in seconds
        """
        self._scope.SetTimeout(seconds)

    def get_log_info(self, clear=True):
        command = "CHL? {}".format("CLR" if clear else "")
        self._scope.WriteString(command, True)
        response = self._scope.ReadString(np.iinfo(np.int_).max)
        return response

    def wait_lecroy(self):
        """
        The WaitForOPC method may be used to wait for previous commands to be interpreted before continuing.
        """
        return self._scope.WaitForOPC()

    def reset_lecroy(self):
        """
        Resets the entire LeCroy oscilloscope
        """
        self._scope.DeviceClear(1)

    def clear_sweeps(self):
        """
        Resets any accumulated average data or persistence data for channel
        waveforms. Valid only when one or more channels have waveform
        averaging or persistence enabled in their pre-processing settings.
        """
        # dir(self._scope)
        self._scope.WriteString('vbs app.Acquisition.ClearSweeps', 1)

    def clear_all(self):
        """
        Resets all parameter setups, turning each of the parameters view to "off",
        the MeasurementType to "measure" and the selected param Engine to Null".
        """
        self._scope.WriteString('vbc app.Measure.ClearAll', 1)

    def prepare_for_trace_capture(self):
        """
        Prepare for trace acquisition by: clearing the sweeps, setting the trigger mode to SINGLE and wait for the PC
        connection to be ready
        """
        # See also page 5-17 of the manual on how to deal with waveform transfers
        """
        Note:On Teledyne LeCroy oscilloscopes, INR status bit 13 iss et high when a trigger is armed, even
        though the oscilloscope may not yet be ready to acquire due to technical limitations. If you are
        concerned with timing a second action on the Trigger Ready state, it is safest to use the result of
        the command TRMD SINGLE;WAIT;*OPC?, which will be 1 when the previous acquisition is fully complete.
        """
        self.enable_wait_lecroy_acquisition()
        time.sleep(0.300)
        self.clear_sweeps()
        self.set_trigger_mode("NORM")

    def save_waveform_data(self, channel_name, file_name, directory="saved_waveforms", as_type="byte"):
        channel_out = None
        channel_out_interpreted = None
        if as_type == "float":
            channel_out, channel_out_interpreted = self.get_native_signal_float(channel_name, 1000000000, 0, False)
        elif as_type == "byte":
            channel_out, channel_out_interpreted = self.get_native_signal_bytes(channel_name, 1000000000,
                                                                                use_word_data_format=False)
        elif as_type == "integer":
            channel_out, channel_out_interpreted = self.get_native_signal_bytes(channel_name, 1000000000,
                                                                                use_word_data_format=True)
        self.write_file(file_name, directory, channel_out)

    def acquire_trace(self, channel="C1"):
        """
        Acquire the waveform used to perform the side channel attack
        :param channel:
        :type channel:
        :return:
        :rtype:
        """
        channel_out = self.get_raw_signal(channel, use_word_data_format=False)
        self.enable_wait_lecroy_acquisition(timeout=5)
        channel_out_interpreted = np.frombuffer(channel_out, dtype="uint8")
        # GetByteWaveform shifts the result with 128 such that it fits in Visual Basic's unsigned byte type
        # We shift it back by: converting to normal int type, apply shift, and convert to signed int8 format
        channel_out_interpreted = channel_out_interpreted.astype(int)
        channel_out_interpreted -= 128
        channel_out_interpreted.astype(np.int8)
        return channel_out_interpreted

    def write_file(self, file_name, directory, content):
        """
        A directory is a "folder", a place where you can put files or other directories
        (and special files, devices, symlinks...). It is a container for filesystem objects.
        A path is a string that specify how to reach a filesystem object
        (and this object can be a file, a directory, a special file, ...).
        :param directory:
        :type directory:
        :param content:
        :type content:
        :param file_name: The file name of the file
        :param dir: The directory in which the file needs to be placed.
        """
        if not os.path.exists(directory):
            try:
                os.makedirs(directory)
            except OSError as exc:  # Guard against race condition
                if exc.errno != errno.EEXIST:
                    raise
        path = os.path.join(directory, file_name)
        with open(path, "wb") as f:
            f.write(content)

    def load_waveform(self, file_path):
        """
        @see https://forum.tek.com/viewtopic.php?t=137002
        :param file_path:
        :type file_path:
        :return:
        :rtype:
        :return:
        """
        if not os.path.exists(file_path):
            return -1
        with open(file_path, "rb") as waveform_file:
            waveform = waveform_file.read()
            return waveform

    def plot_waveform(self, plot_name, plot_dir="plots"):
        """
        Plot a waveform
        :param plot_name:
        :type plot_name:
        :param plot_dir:
        :type plot_dir:
        :param waveform:
        :return:
        """
        number_of_points = np.iinfo(np.int32).max
        step_factor = 500
        channel = "C2"

        # List comprehensions work with the following syntax: [startAt:endBefore:skip]
        out_raw, out_interpreted = self.get_native_signal_bytes(channel, max_bytes=number_of_points,
                                                                use_word_data_format=False,
                                                                block_name="DAT1")
        # Starting from the initial element in the list, take only the elements that are apart by a value the same as
        # the step factor.s
        out_interpreted_applied = out_interpreted[::step_factor]

        # Get waveform description block and retrieve values
        waveform_descriptor_dict = self.get_waveform_description(channel, False)
        voltage_gain = float(waveform_descriptor_dict["VERTICAL_GAIN"])
        voltage_offset = float(waveform_descriptor_dict["VERTICAL_OFFSET"])
        time_interval = float(waveform_descriptor_dict["HORIZ_INTERVAL"])
        time_offset = float(waveform_descriptor_dict["HORIZ_OFFSET"])

        y_float_value = [(out_interpreted_applied[z] * voltage_gain * step_factor - voltage_offset) for z in
                         range(len(out_interpreted_applied))]
        x_float_value = [(time_interval * z * step_factor + time_offset) for z in range(len(out_interpreted_applied))]

        plt.plot(x_float_value, y_float_value)
        self.write_plot_to_pdf(plot_name, plot_dir)

    def write_plot_to_pdf(self, filename, directory, multi_pdf=False):
        """
        Write figure to PDF
        :param multi_pdf:  indicates if a multiPDF is used
        :param filename: the filename
        :param directory: the name of the dir
        """
        try:
            os.makedirs(directory)
        except OSError:
            # path already exists
            pass
        plt.savefig(os.path.join(directory, filename + ".pdf"))
        if not multi_pdf:
            plt.cla()
            plt.clf()
            plt.close('all')

    # TODO determine root of project and take the file from there
    def load_lecroy_cfg(self, load_configuration=False):
        """
        Load the CFG for the oscilloscope.
        We use channel C1 for the trigger and channel C2 for the power capture of FPGA board
        :param load_configuration: Whether to load the configuration file for the Lecroy Waverunner 610Zi Oscilloscope
        or not
        """
        from utils.files import get_full_path
        lecroy_cfg_file = "lecroy_ota_config.dat"
        lecroy_cfg_dir = "lecroy_cfgs"
        if load_configuration:
            self.load_panel_from_file(get_full_path(lecroy_cfg_dir, lecroy_cfg_file))

    def screen_capture(self, file_name, format="PNG", directory="img"):
        """
        Capture the screen of the oscilloscope
        :param file_name: The file name of the screen capture
        :param format: The format in which the screen capture must be stored
        """
        aux_string = 'FORMAT,LANDSCAPE,BCKG,BLACK,AREA,FULLSCREEN'
        path = files.get_full_path(directory, file_name + "." + format)
        self.store_hardcopy_to_file(format, path, aux_string)
