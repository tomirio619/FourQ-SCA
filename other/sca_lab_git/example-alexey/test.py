__author__ = 'yousefhamza'

# import unittest
from aes import AES
import random, os, binascii, array
import numpy


# class AES_TEST(unittest.TestCase):
#     def setUp(self):
#         master_key = 0x2b7e151628aed2a6abf7158809cf4f3c
#         self.AES = AES(master_key)

#     def test_encryption(self):
#         plaintext = 0x3243f6a8885a308d313198a2e0370734
#         encrypted = self.AES.encrypt(plaintext)

#         self.assertEqual(encrypted, 0x3925841d02dc09fbdc118597196a0b32)

#     def test_decryption(self):
#         ciphertext = 0x3925841d02dc09fbdc118597196a0b32
#         decrypted = self.AES.decrypt(ciphertext)

#         self.assertEqual(decrypted, 0x3243f6a8885a308d313198a2e0370734)

#  input gen for AES128 MC attack
def inputgenMC(rng):
    st = b''
    r = random.randint(1, 4)
    for i in range(16):
        if (i + r) % 4 == 0:
            st += chr(random.randint(0, 255))
        else:
            st += chr(0)

    st = b'ca' + binascii.b2a_hex(st).decode() # string generation (command + 16 bytes)
    return array.array('B', st.decode("hex"))

def inputgenSB(rng):
    return array.array('B', b'ca' + binascii.b2a_hex(os.urandom(16)).decode("hex"))

# semi constant AES128 sbox 5 state input generator
def input128TVLA(rng):
    # state = numpy.zeros(16, dtype=numpy.dtype('b'))
    master_key = 0xcabebabedeadbeef0001020304050607
    ciph = AES(master_key)
    state = "00"
    while len(state) != 32:
        state = array.array('B', binascii.b2a_hex('\x00'*16).decode("hex"))
        state[random.randint(0, 15)] = 1 << random.randint(0,7)
        state[random.randint(0, 15)] = 1 << random.randint(0,7)
        state = int(binascii.hexlify(state), 16)
        state = ciph.tvla_decrypt(state)
        print hex(ciph.encrypt(state))[2:-1]
        state = hex(state)[2:-1]
    # print master_key, state
    print state, len(state)
    state = b'ca' + bytearray(state) # string generation (command + 16 bytes)
    print state, len(state)
    return array.array('B', state.decode("hex"))
    # print st, tvla_decr
    # encrypted = ciph.encrypt(tvla_decr)
    # print state, hex(encrypted)
    # return state
    # rx_s_box = state.reshape(4, 4)
    # return array.array('B', state)
    # AES128 decrypt r6.istart == AES encrypt r5.sbox
    # input = Aes.InvCipher(state, expkey, (label,state)-> "r6.istart" == label ? rx_s_box : state)

if __name__ == '__main__':
    # master_key = 0xcabebabedeadbeef0001020304050607
    # AES = AES(master_key)
    # tvla_5out = 0x10000000000000000000000000004000
    # tvla_decr = AES.tvla_decrypt(tvla_5out)
    # print hex(tvla_decr)[2:-1]
    # encrypted = AES.encrypt(tvla_decr)
    # print hex(encrypted), hex(tvla_decr)
    for i in range(20000):
        print input128TVLA(1)