import os
import threading
import time
import logging
import math
import random
import argparse
import sys
import numpy
import struct

import win32com.client #import the pywin32 library

DEBUG_MODE = False

class Lecroy():

    def __init__(self):
        print "[*] Lecroy SETUP"
        command = "LeCroy.ActiveDSOCtrl.1" 
        print "[0] " + command
        self._scope = win32com.client.Dispatch(command)
    
    def __del__(self):
        self.disconnect()
        
    def connect(self,IPAdrress = "192.168.0.1"):
        command = "IP:" + IPAdrress
        print "[0] " + command
        self._scope.MakeConnection(command) 
        command = "*IDN?"
        print "[0] " + command
        self._scope.WriteString(command, 1)
        print "[!] Connected scope:", self._scope.ReadString(80)

    ###
    # Change the volts division of one of the channels
    #
    # @channel
    # String with the name of the channel, can be:
    # "C1", "C2", "C3", "C4",...
    #
    # @return
    # String with the volts division on such channel
    #    
    ###
    def getVoltsDiv(self, channel):
        command = str(channel) + ":VDIV?"
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
        return self._scope.ReadString(80)
        
    ###
    # Change the volts division of one of the channels
    #
    # @channel
    # String with the name of the channel, can be:
    # "C1", "C2", "C3", "C4",...
    #
    # @voltsPerDivision
    # Number of Volts per Division, like "1.0" for 1.0 Volts per division or "0.02" for 20 mV of division
    #    
    ###
    def setVoltsDiv(self, channel, voltsPerDivision):
        command = str(channel) + ":" + "VDIV " + voltsPerDivision
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
    
    def getVoltsOffset(self, channel):
        command = str(channel) + ":" + "OFST?"
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
        return self._scope.ReadString(80)
        
    def setVoltsOffset(self, channel, voltsOffset):
        command = str(channel) + ":" + "OFST " + voltsOffset
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
    
    def getTimeDiv(self):
        command = "TDIV?"
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
        return self._scope.ReadString(80)
        
    def setTimeDiv(self, timeDiv):
        command = "TDIV " + timeDiv
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)

    ###
    # Get the trigger delay
    #
    # @return
    # String with the amount of delay
    # If the value is negative it will be in seconds format ( After the trigger event )
    # If the value is positive it will be a percentage format ( Before the trigger event )
    #    
    ###                 
    def getTriggerDelay(self):
        command = "TRDL?"
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
        return self._scope.ReadString(80)

    ###
    # Set the trigger delay
    #
    # @triggerDelay
    # String with the amount of delay
    # If the value is negative it will be in seconds format ( After the trigger event )
    # If the value is positive it will be a percentage format ( Before the trigger event )
    #    
    ###                 
    def setTriggerDelay(self, triggerDelay):
        command = "TRDL " + triggerDelay
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)

    ###
    # Get the trigger voltage level
    #
    # @channel
    # String with the name of the channel, can be:
    # "C1", "C2", "C3", "C4", "EX" or "EX10"
    #
    # @return
    # String with the amount of Volts
    #    
    ###          
    def getTriggerLevel(self, channel):
        command = channel + ":" + "TRLV?"
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
        return self._scope.ReadString(80)
        
        
    ###
    # Set the trigger voltage level
    #
    # @channel
    # String with the name of the channel, can be:
    # "C1", "C2", "C3", "C4", "EX" or "EX10"
    #
    # @triggerLevel
    # String with the amount of Volts
    #    
    ###                  
    def setTriggerLevel(self, channel, triggerLevel):
        command = channel + ":" + "TRLV " + triggerLevel
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)

    ###
    # Get the trigger mode
    #
    # @return
    # String with the mode of trigger of choice:
    # "AUTO", "NORM", "SINGLE" or "STOP"
    #
    ###                          
    def getTriggerMode(self):
        command = "TRMD?"
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
        return self._scope.ReadString(80)

        
    ###
    # Set the trigger mode
    #
    # @triggerMode
    # String with the mode of trigger of choice:
    # "AUTO", "NORM", "SINGLE" or "STOP"
    #
    ###                          
    def setTriggerMode(self, triggerMode):
        command = "TRMD " + triggerMode
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)

    ###
    # Get the trigger slope of the specified channel
    #
    # @channel
    # String with the name of the channel, can be:
    # "C1", "C2", "C3", "C4", "EX" or "EX10"
    #
    # @return
    # String with the type of slope wanted
    # "POS", "NEG" or "WINDOW"
    #    
    ###         
    def getTriggerSlope(self):
        command = str(channel) + ":" + "TRSL?"
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
        return self._scope.ReadString(80)
        
    ###
    # Set the trigger slope and the channel trigger channel source
    #
    # @channel
    # String with the name of the channel, can be:
    # "C1", "C2", "C3", "C4", "EX" or "EX10"
    #
    # @triggerSlope
    # String with the type of slope wanted
    # "POS", "NEG" or "WINDOW"
    #    
    ###
    def setTriggerSlope(self, channel, triggerSlope):
        command = str(channel) + ":" + "TRSL " + triggerSlope
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
        
    def getPanel(self):
###
###### Code that use the command interface
###
###        command = "PNSU?"
###        if(DEBUG_MODE):
###            print "[0] " + command
###        self._scope.WriteString(command, 1)
###        panel = self._scope.ReadString(1000)
###        buffer = self._scope.ReadString(1000)
###        while(len(buffer) > 0):
###            panel += buffer
###            buffer = self._scope.ReadString(1000)
        panel = self._scope.GetPanel()
        return panel
        
    def setPanel(self, panel):
###
###### Code that use the command interface
###
###        command = "PNSU "
###        if(DEBUG_MODE):
###            print "[0] " + command
###        self._scope.WriteString(command, 0)
###        i = 0
###        while((i + 1000) < len(panel)):
###            buffer = panel[i:(i + 1000)]
###            i = i + 1000
###            self._scope.WriteString(buffer, 0)
###        buffer = panel[i:]
###        self._scope.WriteString(buffer, 1)
        self._scope.SetPanel(panel)
    
    def armAndWaitLecroy(self):
        command = "ARM; WAIT"
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)

    def stopLecroy(self):
        command = "STOP"
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
    
    def enableWaitLecroyAquistion(self):
        command = "WAIT"
        if(DEBUG_MODE):
            print "[0] " + command
        self._scope.WriteString(command,1)
    
    def disconnect(self):
        self._scope.Disconnect()
        
    def loadLecroyPanelFromFile(self, panelFileName):
        panel = ""
        with open(panelFileName, "rt") as f:
            panel = f.read()
            buffer = f.read()
            if(buffer != ''):
                panel += buffer
                buffer = f.read()
        if(panel != ""):
            self._scope.SetPanel(panel)
        
    def storeLecroyPanelToFile(self, panelFileName):
        panel = self._scope.GetPanel()
        with open(fileName, "wt") as f:
            f.write(panel)
        
    def getWaveformBinary(self, channel, bytesFormat=False):
        command = "CFMT DEF9,"
        if(bytesFormat):
            command += "BYTE,"
        else:
            command += "WORD,"
        command += "BIN"
        if(DEBUG_MODE):
            print "[0]" + command
        self._scope.WriteString(command, 1)
        # Command that asks for:
        # all points with no SPacing,
        # Number of Points being maximum,
        # First Point is 0,
        # And all Segment Numbers are acquired.
        command = "WFSU SP,0,NP,0,FP,0,SN,0"
        if(DEBUG_MODE):
            print "[0]" + command
        self._scope.WriteString(command, 1)
        # Bytes are sent with the MSB being the first
        command = "CORD HI"
        if(DEBUG_MODE):
            print "[0]" + command
        self._scope.WriteString(command, 1)
        command = channel + ":" + "WF?" + " DAT1"
        if(DEBUG_MODE):
            print "[0]" + command
        self._scope.WriteString(command, 1)
        waveform = self._scope.ReadBinary(1000)
        buffer = self._scope.ReadBinary(1000)
        while(len(buffer) > 0):
            waveform += buffer
            buffer = self._scope.ReadBinary(1000)
        return waveform
        
    def getWaveformDescryption(self, channel, use2BytesDataFormat=True):
        if(use2BytesDataFormat):
            command = 'CFMT ' + 'DEF9,'+ 'WORD,'+ 'BIN'
            if(DEBUG_MODE):
                print "[0]" + command
            self._scope.WriteString(command, 1)        
        else:
            command = 'CFMT ' + 'DEF9,'+ 'BYTE,'+ 'BIN'
            if(DEBUG_MODE):
                print "[0]" + command
            self._scope.WriteString(command, 1)        
        baseCommand = channel + ":" + "INSPECT?"
        command = baseCommand + ' "VERTICAL_GAIN"'
        if(DEBUG_MODE):
            print "[0]" + command
        self._scope.WriteString(command, 1)
        answerString = self._scope.ReadString(100)
        answerString = answerString.replace('"', '')
        answerString = answerString.replace(':', '')
        voltageGainString = filter(None, answerString.split(' '))[-1]
        voltageGain = float(voltageGainString)
        command = baseCommand + ' "VERTICAL_OFFSET"'
        if(DEBUG_MODE):
            print "[0]" + command
        self._scope.WriteString(command, 1)
        answerString = self._scope.ReadString(100)
        answerString = answerString.replace('"', '')
        answerString = answerString.replace(':', '')
        voltageOffsetString = filter(None, answerString.split(' '))[-1]
        voltageOffset = float(voltageOffsetString)
        command = baseCommand + ' "HORIZ_INTERVAL"'
        if(DEBUG_MODE):
            print "[0]" + command
        self._scope.WriteString(command, 1)
        answerString = self._scope.ReadString(100)
        answerString = answerString.replace('"', '')
        answerString = answerString.replace(':', '')
        timeIntervalString = filter(None, answerString.split(' '))[-1]
        timeInterval = float(timeIntervalString)
        command = baseCommand + ' "HORIZ_OFFSET"'
        if(DEBUG_MODE):
            print "[0]" + command
        self._scope.WriteString(command, 1)
        answerString = self._scope.ReadString(100)
        answerString = answerString.replace('"', '')
        answerString = answerString.replace(':', '')
        timeOffsetString = filter(None, answerString.split(' '))[-1]
        timeOffset = float(timeOffsetString)
        return voltageGain, voltageOffset, timeInterval, timeOffset
    
    ###
    # Get raw data from lecroy on bytes format.
    #
    # @channel
    # String with the name of the channel, like "C1"
    #
    # @numberOfPoints
    # Number of points that want to be acquired
    #    
    # @firstArray
    # For most cases, for raw channel data it should be 0.
    # In case of dual array waveform, it is possible to put 1 to get from the second array.
    #
    # @use2BytesDataFormat
    # If True, then it will return the y-axis values in 2 bytes format. 
    # If False then it will return the y-axis values in 1 byte format. 
    ###
    def getRawSignal(self, channel, numberOfPoints, firstArray=0, use2BytesDataFormat=True):
        startingPoint = 0           # The point to start transfer (0 = first)
        numberOfPointsToJump = 0    # How many points to jump (0 = get all points, 2 = skip every other point) 
        segmentNumber = 0           # Segment number to get, in case of sequence waveforms.
        self._scope.SetupWaveformTransfer(startingPoint, numberOfPointsToJump, segmentNumber)
        if(use2BytesDataFormat):
            return self._scope.GetIntegerWaveform(channel, numberOfPoints, firstArray)
        else:
            return self._scope.GetByteWaveform(channel, numberOfPoints, firstArray)
    
    ###
    # Get internal pre-processed data from lecroy on 1 byte or 2 bytes format.
    # The difference with this method, is because it has already been preprocessed by lecroy.
    #
    # @channel
    # String with the name of the channel, like "C1"
    #
    # @numberOfPoints
    # Number of points that want to be acquired
    # 
    # @use2BytesDataFormat    
    # If chosen to use 16 bits format it is possible to reload lecroy with the same signal.
    # If chosen the 8 bits format, then it is not possible to load lecroy with the signal.
    #
    # @dataFormat
    # What should be included in the data. Only if value is 5, then it supports being loaded with the same signal.
    # 0 - the descriptor (DESC), 
    # 1 - the user text (TEXT), 
    # 2 - the time descriptor (TIME),
    # 3 - the data (DAT1) block 
    # 4 - a second block of data (DAT2)
    # 5 - all entities (ALL)
    #
    ###
    def getNativeSignalBytes(self, channel, numberOfPoints, use2BytesDataFormat=True, dataFormat=3):
        startingPoint = 0           # The point to start transfer (0 = first)
        numberOfPointsToJump = 0    # How many points to jump (0 = get all points, 2 = skip every other point) 
        SegmentNumber = 0           # Segment number to get, in case of sequence waveforms.
        self._scope.SetupWaveformTransfer(startingPoint, numberOfPointsToJump, SegmentNumber)
        if(dataFormat==0):
            internalDataFormat = "DESC"
        elif(dataFormat==1):
            internalDataFormat = "TEXT"
        elif(dataFormat==2):
            internalDataFormat = "TIME"
        elif(dataFormat==3):
            internalDataFormat = "DAT1"
        elif(dataFormat==4):
            internalDataFormat = "DAT2"
        else:
            internalDataFormat = "ALL"
        if(use2BytesDataFormat):
            internalUse2BytesDataFormat = 1
        else:
            internalUse2BytesDataFormat = 0
        receivedBuffer = self._scope.GetNativeWaveform(channel, numberOfPoints, internalUse2BytesDataFormat, internalDataFormat)
        if(use2BytesDataFormat):
            interpretedFormat = numpy.frombuffer(receivedBuffer, dtype='>i2')
        else:
            interpretedFormat = numpy.frombuffer(receivedBuffer, dtype='i1')
        return receivedBuffer, interpretedFormat
        
    ###
    # If you got a wave with getNativeSignalBytes, and chose both use2BytesDataFormat=True and dataFormat=5, then 
    # it is possible to send back to lecroy to some specific channels.
    #
    # @channel
    # String with the name of the channel, the ones that work are "M1", "M2", "M3", "M4"
    #
    # @waveform
    # Waveform obtained by getNativeSignalBytes 
    #
    ###
    def setNativeSignalBytes(self, channel, waveform):
        self._scope.SetNativeWaveform(channel, waveform)
    
    ###
    # Get scaled data from lecroy on float format.
    #
    # @channel
    # String with the name of the channel, like "C1"
    #
    # @numberOfPoints
    # Number of points that want to be acquired
    #    
    # @firstArray
    # For most cases, for raw channel data it should be 0.
    # In case of dual array waveform, it is possible to put 1 to get from the second array.
    #
    # @timeAxis
    #  Select with the time axis or not
    ###
    def getNativeSignalFloat(self, channel, numberOfPoints, firstArray=0, timeAxis=False):
        startingPoint = 0           # The point to start transfer (0 = first)
        numberOfPointsToJump = 0    # How many points to jump (0 = get all points, 2 = skip every other point) 
        segmentNumber = 0           # Segment number to get, in case of sequence waveforms.
        if(timeAxis):
            interpretedFormat = self._scope.GetScaledWaveformWithTimes(channel, numberOfPoints, firstArray)    
            receivedBuffer = [0, 0]
            receivedBuffer[0] = struct.pack(str(len(interpretedFormat[0])) + 'f', *interpretedFormat[0])
            receivedBuffer[1] = struct.pack(str(len(interpretedFormat[1])) + 'f', *interpretedFormat[1])
        else:    
            interpretedFormat = self._scope.GetScaledWaveform(channel, numberOfPoints, firstArray)
            receivedBuffer = struct.pack(str(len(interpretedFormat)) + 'f', *interpretedFormat)
        return receivedBuffer, interpretedFormat
        
    ##
    # Set timeout in seconds
    #
    ##
    def setTransfersTimeout(self, seconds=10):
        self._scope.SetTimeout(seconds)
    
    def waitLecroy(self):
        return self._scope.WaitForOPC()
    ##
    # Resets the entire lecroy
    ##
    def resetLecroy(self):
        self._scope.DeviceClear(1)
    
def print_main_class_help():
    print 'The parameters options are:'
    print 
    print 'lecroy.py -r'
    print "Reset Lecroy."
    print 
    print 'lecroy.py -l "LecroyPanel.dat"'
    print "To load Lecroy with a panel."
    print 
    print 'lecroy.py -s "LecroyPanel.dat"'
    print 'To store current Lecroy panel into the file "LecroyPanel.dat"'
    print 
    print 'lecroy.py -wb "C1" "WaveformByteFormat"'
    print 'To store chanel "C1", "C2", "C3" or "C4" y-axis Waveform in Byte format (8 bits) into the file "WaveformByteFormat"'
    print 
    print 'lecroy.py -wi "C1" "WaveformIntegerFormat"'
    print 'To store chanel "C1", "C2", "C3" or "C4" y-axis Waveform in Integer format (16 bits) into the file "WaveformByteFormat"'
    print 
    print 'lecroy.py -wf "C1" "WaveformFloatFormat"'
    print 'To store chanel "C1", "C2", "C3" or "C4" y-axis Waveform in Float format (32 bits) into the file "WaveformByteFormat"'


if __name__ == "__main__":
    argc = len(sys.argv)
    if argc == 4:
        _, waveform, channelName, fileName = sys.argv
        channel_out, channel_out_interpreted = None, None
        if waveform in ['-wb', '-wi', '-wf']:
            print 'Trying to store channel: ' + str(channelName) + ' Waveform in file: ' + fileName
            le = Lecroy()
            le.connect()
            if waveform == "-wb":
                channel_out, channel_out_interpreted = le.getNativeSignalBytes(channelName, 1000000000, False, 3)
            elif waveform == "-wi":
                channel_out, channel_out_interpreted = le.getNativeSignalBytes(channelName, 1000000000, True, 3)
            elif waveform == "-wf":
                channel_out, channel_out_interpreted = le.getNativeSignalFloat(channelName, 1000000000, 0, False)
            else:
                print "Something weird happened"

            with open(fileName, "wb") as f:
                f.write(channel_out)
            le.disconnect()
        else:
            print 'Unknown parameter'
            print 
            print_main_class_help()
    elif argc == 3:
        _, op, fileName = sys.argv
        if op in ['-s', '-l']:
            le = Lecroy()
            le.connect()
            if op == '-s':
                print 'Trying to save Panel into file: ' + fileName
                le.storeLecroyPanelToFile(fileName)
            elif op == '-l':
                print 'Trying to load Panel from file: ' + fileName
                le.loadLecroyPanelFromFile(fileName)
            le.disconnect()
        else:
            print 'Unknown parameter'
            print 
            print_main_class_help()
    elif argc == 2:
        if sys.argv[1] == '-r':
            le = Lecroy()
            le.connect()
            le.resetLecroy()
            le.disconnect()
        else:
            print 'Unknown parameter'
            print 
            print_main_class_help()
    else:
        print "Wrong number of parameters."
        print 
        print_main_class_help()
