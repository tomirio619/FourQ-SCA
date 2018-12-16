import serial
from array import array
import time
import os
import binascii
from Crypto.Cipher import AES

if __name__ == '__main__':

    # Pinata serial port settings  
    ser = serial.Serial(
        port='COM25',
        baudrate=115200,
        timeout=10,
        write_timeout=1,
        inter_byte_timeout=1,
        xonxoff = 0
    )
    print(ser.isOpen())
    while True:
        time.sleep(1)

        data_input = '31303130313031303130313031303131'.decode('hex')
        # data_input = '1111111111111111'


        obj = AES.new('cafebabedeadbeef0001020304050607'.decode('hex'), AES.MODE_ECB)
        rrr = obj.encrypt(data_input)
        print rrr.encode('hex')
        res = ""

        #st = b'CA' + binascii.b2a_hex(os.urandom(16)).decode() # string generation (command + 16 bytes)
        #data_input = array('B', st.decode("hex"))
        # for i in data_input:
        #     print ord(i)
        data_input = "ca31303130313031303130313031303131".decode('hex')
        #print data_input
        # for i in data_input:
        ser.write(data_input)

        time.sleep(0.1)
        data_output = ''
        # for i in range(16):
        data_output += ser.read(16)
        print data_input, data_output.encode("hex")
        print "1"
    #print data_output
    ser.close()
