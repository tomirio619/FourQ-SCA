#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2013-2014, NewAE Technology Inc
# All rights reserved.
#
#    Class SASEBOGII is part of chipwhisperer.
#
#    chipwhisperer is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    chipwhisperer is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Lesser General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with chipwhisperer.  If not, see <http://www.gnu.org/licenses/>.
#=================================================
import time
import ftd2xx as ft

def integerToBytearray(a):
    bytearray_a = bytearray()
    i = 1
    while a != 0:
        bytearray_a.append(a%256)
        i = i * 256
        a = a//256
    return bytearray_a

def bytearrayToInteger(a):
    integer_a = 0
    j = 1
    for i in range(len(a)):
        integer_a = integer_a + a[i]*j
        j = j * 256
    return integer_a

class SASEBOGII():
    
    def connect(self, serialNo):
        # connect to port
        try:
            self.sasebo = ft.openEx(serialNo)
            #['FTYJVALDA', 'FTYJVALDB']

        except ft.ftd2xx.DeviceError, e:
            self.sasebo = None
            return False
            
        self.sasebo.setTimeouts(20000, 20000)
        return True
        
    def disconnect(self):
        return

    def flush(self):
        num = self.sasebo.getQueueStatus()
        if num > 0:
            self.sasebo.read(num)
            
    def write(self, address, value_bytearray):
        msg = bytearray(18)
        
        msg[0] = 0x02;
        msg[1] = address & 0xFF;
        for i in range(16):
            msg[i + 2] = value_bytearray[i]
        strmsg = str(msg);

        #msg = bytearray(strmsg)
        #print "Write: %x %x %x %x %x"%(msg[0],msg[1],msg[2],msg[3],msg[4])

        self.sasebo.write(strmsg)

    def read(self, address):
        self.flush()
        
        send_msg = bytearray(2)
        
        send_msg[0] = 0x01;
        send_msg[1] = address & 0xFF;
        
        self.sasebo.write(str(send_msg))
        
        #print "Write: %x %x %x"%(msg[0],msg[1],msg[2]),
        
        response_msg = self.sasebo.read(16)
        response_msg = bytearray(response_msg)

        #print " Read: %x %x"%(msg[0],msg[1])
        #Order = MSB, LSB
        
        #print "Response " + str(response_msg)

        return response_msg
        
    def close(self):
        self.sasebo.close()
   
    def isFree(self):
        self.flush()
        
        send_msg = bytearray(1)
        
        send_msg[0] = 0x04;
        
        self.sasebo.write(str(send_msg))
        
        #print "Write: %x %x %x"%(msg[0],msg[1],msg[2]),
        
        response_msg = self.sasebo.read(1)
        response_msg = bytearray(response_msg)

        #print " Read: %x %x"%(msg[0],msg[1])
        #Order = MSB, LSB
        
        print "Response " + str(response_msg)
        
        if(response_msg[0] == 0x01):
            return True
        else:
            return False
            
    def startComputation(self):
        msg = bytearray(1)
        
        msg[0] = 0x03;
        strmsg = str(msg);

        #msg = bytearray(strmsg)
        #print "Write: %x %x %x %x %x"%(msg[0],msg[1],msg[2],msg[3],msg[4])

        self.sasebo.write(strmsg)
        
testData = integerToBytearray(int("00011010000000101111111110110000110100110111011110001011110010100010010101111011010001001001110000101011011001000011101100110010", base=2))
testKey1 = integerToBytearray(int("00100010000110110100010110100001110110111011000111110011010001011110000001001100010111001001110110111001101001011100000101011100", base=2))
testKey2 = integerToBytearray(int("00100100000101100101000010101111100100010111101111100001100000111010000101100001001101010100000010010010001010110001001011011011", base=2))
TrueCiphertext1 = integerToBytearray(int("10101101010001111110001010010101111100011100111011001001000110100011110111001001101111000110010001011010110101110011101100111001", base=2))
TrueCiphertext2 = integerToBytearray(int("10101110010110101110011110001101101001100100100011010101000000011111000100000111011001011001011011011010110100010110011100011111", base=2))
TrueCiphertext3 = integerToBytearray(int("01011100010100110100110100001110001001000011111110011010000111010010001011011100000100111101111000110110111111110010000110101010", base=2))

print "[*] Sakura SETUP"
# List FTDI devices
ftdiDevices = ft.listDevices()
print "Devices:", ftdiDevices
# Select the first FPGA ("A", the control FPGA)
sakura = SASEBOGII()
print "Connection to Sakura G, FPGA:", ftdiDevices[0], "Result:", sakura.connect(ftdiDevices[0])    
sakura.write(0, testData)
sakura.write(1, testKey1)
sakura.write(2, testKey2)
sakura.startComputation()
time.sleep(2)
receivedCiphertext1 = sakura.read(4)
receivedCiphertext2 = sakura.read(5)
receivedCiphertext3 = sakura.read(6)
print (bytearrayToInteger(TrueCiphertext1))
print (bytearrayToInteger(receivedCiphertext1))
print (bytearrayToInteger(TrueCiphertext2))
print (bytearrayToInteger(receivedCiphertext2))
print (bytearrayToInteger(TrueCiphertext3))
print (bytearrayToInteger(receivedCiphertext3))
if((TrueCiphertext1 != receivedCiphertext1) or (TrueCiphertext2 != receivedCiphertext2) or (TrueCiphertext3 != receivedCiphertext3)):
    print "There was an error"
print "End of the test"
