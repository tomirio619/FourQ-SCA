import os
import time
import struct
import serial
from ctypes import *
import binascii
import random

from lecroy import *
from array import array
from aes import AES
random.seed(1)

def create_header(scope_context,
                  num_traces, num_samples, sample_coding, data_length, global_title,
                  description, x_label, y_label, x_scale,
                  v_range, coupling, scope_id):

    # Header is documented in appendix K of the inspector user manual.

    SAMPLE_CODING_FLOAT = 0b00010000
    SAMPLE_CODING_BYTE =  0b00000000
    SAMPLE_CODING_LENGTH_1 = 0b00000001
    SAMPLE_CODING_LENGTH_2 = 0b00000010
    SAMPLE_CODING_LENGTH_4 = 0b00000100

    #TODO: implement sample coding.

    # Number of traces (mandatory)
    header = bytearray()
    header.extend(create_header_field(0x41, c_uint32(num_traces)))
    # Number of samples per trace (mandatory)
    header.extend(create_header_field(0x42, c_uint32(num_samples)))
    # Sample encoding (float / byte, length per sample) (mandatory)
    # Note that we're shifting down to single bytes!
    header.extend(
        create_header_field(0x43, SAMPLE_CODING_BYTE | SAMPLE_CODING_LENGTH_1))
    # Data space
    header.extend(create_header_field(0x44, c_uint16(data_length)))
    # Global trace title
    header.extend(create_header_field(0x46, global_title))
    # Global description
    header.extend(create_header_field(0x47, description))
    # X axis label
    header.extend(create_header_field(0x49, x_label))
    # Y axis label
    header.extend(create_header_field(0x4a, y_label))
    # X axis scaling
    header.extend(create_header_field(0x4b, c_float(x_scale)))
    # Y axis scaling
    # Multiply by 256 because of the downshift to single bytes
    header.extend(create_header_field(0x4c, c_float(v_range * 256)))
    # Scope range
    header.extend(create_header_field(0x55, c_float(v_range)))
    # Scope coupling
    header.extend(create_header_field(
        0x56, c_uint32(coupling)))
    # Scope ID
    header.extend(create_header_field(0x59, scope_id))
    # Header end
    header.append(0x5f)
    header.append(0x00)
    return header


def create_header_field(tag, valuebytes):
    header = bytearray()
    try:
        length = len(valuebytes)
    except TypeError as e:
        if isinstance(valuebytes, c_uint32) or isinstance(valuebytes, c_float):
            length = 4
        elif isinstance(valuebytes, c_uint16):
            length = 2
        elif isinstance(valuebytes, int):
            length = 1
            valuebytes = [valuebytes]
        else:
            raise e

    header.append(tag)
    if length >= 128:
        header.append(0b10000000 | 4)
        header.extend(c_uint32(length))
    else:
        header.append(length)
    header.extend(valuebytes)
    return header

def sequence_header(inp, out):
    header = bytearray()
    valuebytes = [valuebytes]


#  input gen for AES128 MC attack
def inputgenMC(rng):
    st = b''
    r = random.randint(1, 4)
    for i in range(16):
        if (i + r) % 4 == 0:
            st += chr(random.randint(0, 255))
        else:
            st += chr(0)

    st = b'cb' + binascii.b2a_hex(st).decode() # string generation (command + 16 bytes)
    return array('B', st.decode("hex"))

def inputgenSB(rng):
    return array('B', b'cb' + binascii.b2a_hex(os.urandom(16)).decode("hex"))


# semi constant AES128 sbox 5 state input generator
def input128TVLA(rng):
    # state = numpy.zeros(16, dtype=numpy.dtype('b'))
    master_key = 0xcabebabedeadbeef0001020304050607
    ciph = AES(master_key)
    state = "00"
    while len(state) != 32:
        state = array('B', binascii.b2a_hex('\x00'*16).decode("hex"))
        state[random.randint(0, 15)] = 1 << random.randint(0,7)
        state[random.randint(0, 15)] = 1 << random.randint(0,7)
        state = int(binascii.hexlify(state), 16)
        state = ciph.tvla_decrypt(state)
        # print hex(ciph.encrypt(state))[2:-1]
        state = hex(state)[2:-1]
    # print master_key, state
    # print state, len(state)
    state = b'cb' + bytearray(state) # string generation (command + 16 bytes)
    # print state, len(state)
    return array('B', state.decode("hex"))



loadLecroyPanelEnabled = False
lecroyPanelFileName = "hwaes.bin"

if __name__ == '__main__':

    start_time = time.time()

    # Lecroy settings
    le = Lecroy()
    le.connect()     
    if(loadLecroyPanelEnabled):
        le.loadLecroyPanelFromFile(lecroyPanelFileName)

    # Pinata serial port settings
    ser = serial.Serial(
        port='COM25',
        baudrate=115200,
        timeout=5,
    )
    # print ser.isOpen()
    time.sleep(1)
    # number of acquisitions
    allGroupTests = 35000
    groupIterations = 5000

    # Configure output files
    traceFileName = "traces/" + str(int(time.time()))+".trs"
    traceFile = open(traceFileName, "wb")
    commFileName = "traces/" + str(int(time.time()))+".txt"
    commFile = open(commFileName, "w")

    header = {
        'scopeContext': None,
        'numTraces': allGroupTests,
        'numSamples': 2000, 
        'sampleConding': 0x01,
        'dataLength': 32,                               
        'globalTitle': '',
        'description': '',
        'x_label': "ns",
        'y_label': "mV",
        'sampleInterval': 1e-9, #0.00000000001
        'voltageRange': 6e-2,
        'coupling': 0,
        'scopeSerial':''
    }

    numPoints = groupIterations * header['numSamples']
    numTotal = 0


    # traceFile.seek(0, 0)
    # write header to the file
    traceFile.write(create_header(header['scopeContext'],
                                  header['numTraces'],
                                  header['numSamples'],
                                  header['sampleConding'],
                                  header['dataLength'],
                                  header['globalTitle'],
                                  header['description'],
                                  header['x_label'],
                                  header['y_label'],
                                  header['sampleInterval'],
                                  header['voltageRange'],
                                  header['coupling'],
                                  header['scopeSerial']
                                ))
    # Main loop
    while numTotal < allGroupTests:
        le.clearSweeps()
        le.setTriggerMode("SINGLE")
        le.waitLecroy()
        try:

            res = ""
            data_input = input128TVLA(1)

            ser.write(data_input)
            time.sleep(0.052)
            data_output = ser.read(16)
            
            channel_out = le.getRawSignal("C2", numPoints, 0, False)
            try:
                channel_out_interpreted = numpy.frombuffer(channel_out, dtype='int8')
                _len = int(len(channel_out) / groupIterations)
                # print len(channel_out)
                channel_out_interpreted = channel_out_interpreted.reshape(groupIterations, _len)

                channel_out_interpreted = channel_out_interpreted - numpy.int8(128)
                channel_out_interpreted = numpy.mean(channel_out_interpreted, axis=0)
                channel_out_interpreted = channel_out_interpreted.astype(numpy.int8)

            except Exception as ex:
                print ex

            numTotal += 1

            commFile.write(">> " + binascii.hexlify(data_input)[2:34] + "\n")
            commFile.write("<< " + str(data_output.encode("hex")) + "\n")

            traceFile.write(data_input[1:17])
            traceFile.write(data_output)
            traceFile.write(channel_out_interpreted[0:header['numSamples']])

        except Exception as ex:
            print "ERROR: ", ex

        if numTotal % 10000 == 0:
            print numTotal

    traceFile.close()
    commFile.close()
    le.disconnect()
    ser.close()

    print "Done: " + str(numTotal)
    print "Total time: " + str(time.time() - start_time)