import mpmath
from mpmath import *

# This statement is needed to ensure operations are calculated with enough precision
mpmath.mp.dps = 9000

# @formatter:off

# 246-bit prime, see Equation (2) in paper (i.e. the order of the group)
N   = 73846995687063900142583536357581573884798075859800097461294096333596429543
r   = 15437785290780909242
V   = 49293975489306344711751403123270296814
mu = 2 ** 256
p   = 2 ** 127 - 1
d   = mpmath.mpc(4205857648805777768770, 125317048443780598345676279555970305165)
a   = -1

# Constants for Endomorphisms
"""
NOTE: these constants include all of the fixed additions/multiplications that can also be included in them.
For example, in dual map of tau, we see that in the numerator of the new x value, the calculation 2*x*y*sqrt(d_hat) is 
done. The constant d_hat will also include the multiplication with 2. In the normal map of Tau, we can already calculate
the modular inversion of sqrt(d_hat) and multiply the value with 2.
"""

ctau        = mpc(0x1964de2c3afad20c74dcd57cebce74c3, 0x000000000000000c0000000000000012)
ctaudual    = mpc(0x4aa740eb230586529ecaa6d9decdf034, 0x7ffffffffffffff40000000000000011)

cphi0       = mpc(0x0000000000000005fffffffffffffff7, 0x2553a0759182c3294f65536cef66f81a)
cphi1       = mpc(0x00000000000000050000000000000007, 0x62c8caa0c50c62cf334d90e9e28296f9)
cphi2       = mpc(0x000000000000000f0000000000000015, 0x78df262b6c9b5c982c2cb7154f1df391)
cphi3       = mpc(0x00000000000000020000000000000003, 0x5084c6491d76342a92440457a7962ea4)
cphi4       = mpc(0x00000000000000030000000000000003, 0x12440457a7962ea4a1098c923aec6855)
cphi5       = mpc(0x000000000000000a000000000000000f, 0x459195418a18c59e669b21d3c5052df3)
cphi6       = mpc(0x00000000000000120000000000000018, 0x0b232a8314318b3ccd3643a78a0a5be7)
cphi7       = mpc(0x00000000000000180000000000000023, 0x3963bc1c99e2ea1a66c183035f48781a)
cphi8       = mpc(0x00000000000000aa00000000000000f0, 0x1f529f860316cbe544e251582b5d0ef0)
cphi9       = mpc(0x00000000000008700000000000000bef, 0x0fd52e9cfe00375b014d3e48976e2505)
cpsi1       = mpc(0x2af99e9a83d54a02edf07f4767e346ef, 0x00000000000000de000000000000013a)
cpsi2       = mpc(0x00000000000000e40000000000000143, 0x21b8d07b99a81f034c7deb770e03f372)
cpsi3       = mpc(0x00000000000000060000000000000009, 0x4cb26f161d7d69063a6e6abe75e73a61)
cpsi4       = mpc(0x7ffffffffffffff9fffffffffffffff6, 0x334d90e9e28296f9c59195418a18c59e)

basis1 = [0x0906ff27e0a0a196, -0x1363e862c22a2da0,  0x07426031ecc8030f, -0x084f739986b9e651]
basis2 = [0x1d495bea84fcc2d4, -0x0000000000000001,  0x0000000000000001,  0x25dbc5bc8dd167d0]
basis3 = [0x17abad1d231f0302,  0x02c4211ae388da51, -0x2e4d21c98927c49f,  0x0a9e6f44c02ecd97]
basis4 = [0x136e340a9108c83f,  0x3122df2dc3e0ff32, -0x068a49f02aa8a9b5, -0x18d5087896de0aea]

L1 = 0x7fc5bb5c5ea2be5dff75682ace6a6bd66259686e09d1a7d4f
L2 = 0x38fd4b04caa6c0f8a2bd235580f468d8dd1ba1d84dd627afb
L3 = 0x0d038bf8d0bffbaf6c42bd6c965dca9029b291a33678c203c
L4 = 0x31b073877a22d841081cbdc3714983d8212e5666b77e7fdc0

# @formatter:on