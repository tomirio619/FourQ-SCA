import sys
import os
import threading
import time
import logging
import math
import ftd2xx as ft
import h5py
import argparse
import numpy
import sys
import struct
from random import randint

from time import gmtime, strftime
from binascii import hexlify, b2a_hex

from sakura_ecp import *
from lecroy import *

import matplotlib.pyplot as plt

from array import array

DEBUG_MODE = False
SHOW_GRAPH = False

def integer_to_list(word_size, list_size, a):
    list_a = [0 for i in range(list_size)]
    modulus = 2**(word_size)
    j = 1
    for i in range(list_size):
        list_a[i] = (a//j)%(modulus)
        j = j*(modulus)
    return list_a

def list_to_integer(word_size, list_size, list_a):
    a = 0
    modulus = 2**(word_size)
    j = 1
    for i in range(list_size):
        a = a + list_a[i]*j
        j = j*(modulus)
    return a

def integer_to_writable_string(a, finalSizeBits=0):
    if(finalSizeBits == 0):
        list_a = integer_to_list(8, (a.bit_length() + 7)//8, a)
    else:
        list_a = integer_to_list(8, (finalSizeBits + 7)//8, a)
    final = struct.pack('B', list_a[0])
    for i in range(1, len(list_a)):
        final += struct.pack('B', list_a[i])
    return final

def square_root(a, prime):
    legendre_symbol = pow(a, (prime-1)//2, prime)
    if(legendre_symbol != 1):
        return 0, 0
    if((prime % 4) == 3):
        R = pow(a, (prime+1)//4, prime)
        return R, prime - R        
    S = 0
    Q = prime - 1
    while((Q% 2) == 0):
        S += 1
        Q = Q//2
    z = 2
    while(pow(z, (prime-1)//2, prime) != -1):
        z = randint(3, prime-1)
    c = pow(z, Q, prime)
    R = pow(a, (Q+1)//2, prime)
    t = pow(a, Q, prime)
    M = S
    while(t != 1):
        i = 0
        temp = pow(t, 2**i, prime)
        while(temp != 1):
            i = i + 1
            temp = pow(t, 2**i, prime)
        b = pow(c, 2**(M - i - 1), prime)
        R = (R*b) % prime
        c = (b*b) % prime
        t = (t*c) % prime
        M = i
    return R, prime - R
    
def cube_root(a, prime):
    if((prime % 3) == 2):
        return pow(a,(2*prime - 1)//3, prime)
    if((prime % 9) == 4):
        root = pow(a,(2*prime + 1)//9, prime)
        if(pow(root, 3, prime) == a % prime):
            return root
        else:
            return 0
    if((prime % 9) == 7):
        root = pow(a,(prime + 2)/9, prime)
        if(pow(root,3,prime) == a%prime):
            return root
        else:
            return 0
    s = 0
    t = prime - 1
    while((t % 3) == 0):
        s += 1
        t = t//3
    b = 2
    while(pow(b, (prime-1)//2, prime) != ((-1) % prime)):
        b = randint(3, prime-1)
    c = pow(b, t, prime)
    r = pow(a, t, prime)
    h = 1
    c_prime = pow(c, 3**(s-1), prime)
    c = pow(c, prime - 2, prime)
    for i in range(1, s - 1):
        d = pow(r, 3**(s - i - 1), prime)
        if(d == c_prime):
            h = (h*c) % prime
            r = (r*pow(c, 3, prime)) % prime
        elif(d != 1):
            l = c*c % prime
            h = (h*l) % prime
            r = (r*pow(l, 3, prime)) % prime
        c = pow(c, 3, prime)
    k = t//3
    if(t % 3 == 2):
        k = k + 1
    r = pow(a, k, prime)
    r = (r * h) % prime
    if(t % 3 == 1):
        r = pow(r, prime - 2, prime)
    return r

    
def short_weierstrass_point_addition_complete_a_m3_1(curve_constants, point_a, point_b, prime):
    short_weierstrass_b = curve_constants[1]
    
    point_o = [0, 0, 0]
    
    ## 01 ##
    ## t0 = X1*X2; //
    temp_0 = (point_a[0]*point_b[0]) % prime
    ## 02 ##
    ## t1 = Y1*Y2; //
    temp_1 = (point_a[1]*point_b[1]) % prime
    ## 03 ##
    ## t2 = Z1*Z2; //
    temp_2 = (point_a[2]*point_b[2]) % prime
    ## 04 ##
    ## t3 = X1+Y1; //
    temp_3 = (point_a[0]+point_a[1]) % prime
    ## 05 ##
    ## t4 = X2+Y2; //
    temp_4 = (point_b[0]+point_b[1]) % prime
    ## 06 ##
    ## t3 = t3*t4; //
    temp_3 = (temp_3*temp_4) % prime
    ## 07 ##
    ## t4 = t0+t1; //
    temp_4 = (temp_0+temp_1) % prime
    ## 08 ##
    ## t3 = t3-t4; //
    temp_3 = (temp_3-temp_4) % prime
    ## 09 ##
    ## t4 = Y1+Z1; //
    temp_4 = (point_a[1]+point_a[2]) % prime
    ## 10 ##
    ## t5 = Y2+Z2; //
    temp_5 = (point_b[1]+point_b[2]) % prime
    ## 11 ##
    ## t4 = t4*t5; //
    temp_4 = (temp_4*temp_5) % prime
    ## 12 ##
    ## t5 = t1+t2; //
    temp_5 = (temp_1+temp_2) % prime
    ## 13 ##
    ## t4 = t4-t5; //
    temp_4 = (temp_4-temp_5) % prime
    ## 14 ##
    ## t5 = X1+Z1; //
    temp_5 = (point_a[0]+point_a[2]) % prime
    ## 15 ##
    ## t6 = X2+Z2; //
    temp_6 = (point_b[0]+point_b[2]) % prime
    ## 16 ##
    ## t5 = t5*t6; //
    temp_5 = (temp_5*temp_6) % prime
    ## 17 ##
    ## t6 = t0+t2; //
    temp_6 = (temp_0+temp_2) % prime
    ## 18 ##
    ## t6 = t5-t6; //
    temp_6 = (temp_5-temp_6) % prime
    ## 19 ##
    ## t7 = b*t2; //
    temp_7 = (short_weierstrass_b*temp_2) % prime
    ## 20 ##
    ## t5 = t6-t7; //
    temp_5 = (temp_6-temp_7) % prime
    ## 21 ##
    ## t7 = t5+t5; //
    temp_7 = (temp_5+temp_5) % prime
    ## 22 ##
    ## t5 = t5+t7; //
    temp_5 = (temp_5+temp_7) % prime
    ## 23 ##
    ## t7 = t1-t5; //
    temp_7 = (temp_1-temp_5) % prime
    ## 24 ##
    ## t5 = t1+t5; //
    temp_5 = (temp_1+temp_5) % prime
    ## 25 ##
    ## t6 = b*t6;//
    temp_6 = (short_weierstrass_b*temp_6) % prime
    ## 26 ##
    ## t1 = t2+t2; //
    temp_1 = (temp_2+temp_2) % prime
    ## 27 ##
    ## t2 = t1+t2; //
    temp_2 = (temp_1+temp_2) % prime
    ## 28 ##
    ## t6 = t6-t2; //
    temp_6 = (temp_6-temp_2) % prime
    ## 29 ##
    ## t6 = t6-t0; //
    temp_6 = (temp_6-temp_0) % prime
    ## 30 ##
    ## t1 = t6+t6; //
    temp_1 = (temp_6+temp_6) % prime
    ## 31 ##
    ## t6 = t1+t6; //
    temp_6 = (temp_1+temp_6) % prime
    ## 32 ##
    ## t1 = t0+t0; //
    temp_1 = (temp_0+temp_0) % prime
    ## 33 ##
    ## t0 = t1+t0; //
    temp_0 = (temp_1+temp_0) % prime
    ## 34 ##
    ## t0 = t0-t2; //
    temp_0 = (temp_0-temp_2) % prime
    ## 35 ##
    ## t1 = t4*t6; //
    temp_1 = (temp_4*temp_6) % prime
    ## 36 ##
    ## t2 = t0*t6; //
    temp_2 = (temp_0*temp_6) % prime
    ## 37 ##
    ## t6 = t5*t7; //
    temp_6 = (temp_5*temp_7) % prime
    ## 38 ##
    ## Y3 = t6+t2; //
    point_o[1] = (temp_6+temp_2) % prime
    ## 39 ##
    ## t5 = t3*t5; //
    temp_5 = (temp_3*temp_5) % prime
    ## 40 ##
    ## X3 = t5-t1; //
    point_o[0] = (temp_5-temp_1) % prime
    ## 41 ##
    ## t7 = t4*t7; //
    temp_7 = (temp_4*temp_7) % prime
    ## 42 ##
    ## t1 = t3*t0; //
    temp_1 = (temp_3*temp_0) % prime
    ## 43 ##
    ## Z3 = t7+t1; //
    point_o[2] = (temp_7+temp_1) % prime
    
    return point_o



def short_weierstrass_point_doubling_complete_a_m3_1(curve_constants, point_a, prime):    
    short_weierstrass_b = curve_constants[1]
    
    point_o = [0, 0, 0]
    
    ## 01 ##
    ## t0 = X1*X1; //
    temp_0 = (point_a[0]*point_a[0]) % prime
    ## 02 ##
    ## t1 = Y1*Y1; //
    temp_1 = (point_a[1]*point_a[1]) % prime
    ## 03 ##
    ## t2 = Z1*Z1; //
    temp_2 = (point_a[2]*point_a[2]) % prime
    ## 04 ##
    ## t3 = X1*Y1; //
    temp_3 = (point_a[0]*point_a[1]) % prime
    ## 05 ##
    ## t3 = t3+t3; //
    temp_3 = (temp_3+temp_3) % prime
    ## 06 ##
    ## t6 = X1*Z1; //
    temp_6 = (point_a[0]*point_a[2]) % prime
    ## 07 ##
    ## t6 = t6+t6; //
    temp_6 = (temp_6+temp_6) % prime
    ## 08 ##
    ## t5 = b*t2; //
    temp_5 = (short_weierstrass_b*temp_2) % prime
    ## 09 ##
    ## t5 = t5-t6; //
    temp_5 = (temp_5-temp_6) % prime
    ## 10 ##
    ## t4 = t5+t5; //
    temp_4 = (temp_5+temp_5) % prime
    ## 11 ##
    ## t5 = t4+t5; //
    temp_5 = (temp_4+temp_5) % prime
    ## 12 ##
    ## t4 = t1-t5; //
    temp_4 = (temp_1-temp_5) % prime
    ## 13 ##
    ## t5 = t1+t5; //
    temp_5 = (temp_1+temp_5) % prime
    ## 14 ##
    ## t5 = t4*t5; //
    temp_5 = (temp_4*temp_5) % prime
    ## 15 ##
    ## t4 = t4*t3; //
    temp_4 = (temp_4*temp_3) % prime
    ## 16 ##
    ## t3 = t2+t2; //
    temp_3 = (temp_2+temp_2) % prime
    ## 17 ##
    ## t2 = t2+t3; //
    temp_2 = (temp_2+temp_3) % prime
    ## 18 ##
    ## t6 = b*t6; //
    temp_6 = (short_weierstrass_b*temp_6) % prime
    ## 19 ##
    ## t6 = t6-t2; //
    temp_6 = (temp_6-temp_2) % prime
    ## 20 ##
    ## t6 = t6-t0; //
    temp_6 = (temp_6-temp_0) % prime
    ## 21 ##
    ## t3 = t6+t6; //
    temp_3 = (temp_6+temp_6) % prime
    ## 22 ##
    ## t6 = t6+t3; //
    temp_6 = (temp_6+temp_3) % prime
    ## 23 ##
    ## t3 = t0+t0; //
    temp_3 = (temp_0+temp_0) % prime
    ## 24 ##
    ## t0 = t3+t0; //
    temp_0 = (temp_3+temp_0) % prime
    ## 25 ##
    ## t0 = t0-t2; //
    temp_0 = (temp_0-temp_2) % prime
    ## 26 ##
    ## t0 = t0*t6; //
    temp_0 = (temp_0*temp_6) % prime
    ## 28 ##
    ## t2 = Y1*Z1; //
    temp_2 = (point_a[1]*point_a[2]) % prime
    ## 29 ##
    ## t2 = t2+t2; //
    temp_2 = (temp_2+temp_2) % prime
    ## 27 ##
    ## Y3 = t5+t0; //
    point_o[1] = (temp_5+temp_0) % prime
    ## 30 ##
    ## t6 = t2*t6; //
    temp_6 = (temp_2*temp_6) % prime
    ## 31 ##
    ## X3 = t4-t6; //
    point_o[0] = (temp_4-temp_6) % prime
    ## 32 ##
    ## t6 = t2*t1; //
    temp_6 = (temp_2*temp_1) % prime
    ## 33 ##
    ## t6 = t6+t6; //
    temp_6 = (temp_6+temp_6) % prime
    ## 34 ##
    ## Z3 = t6+t6; //
    point_o[2] = (temp_6+temp_6) % prime

    return point_o
    
def scalar_point_multiplication_2(curve_parameters, point, scalar):
    prime = curve_parameters[1]
    curve_constants = curve_parameters[5]
    coordinate_system = curve_parameters[7]
    point_infinity = coordinate_system[2]
    r0_point = [0 for i in range(len(point_infinity))]
    r1_point = [0 for i in range(len(point_infinity))]
    curve_constants_field = [0 for i in range(len(curve_constants))]
    
    scalar_list = integer_to_list(1, scalar.bit_length()+1, scalar)
    
    point_addition = coordinate_system[5]
    point_doubling = coordinate_system[6] 
    
    
    for i in range(len(point_infinity)):
        r0_point[i] = point_infinity[i] % prime
    
    for i in range(len(point_infinity)):
        r1_point[i] = point[i] % prime
    
    for i in range(len(curve_constants)):
        curve_constants_field[i] = curve_constants[i] % prime
        curve_constants_field[i] = curve_constants_field[i] % prime
    
    i = len(scalar_list) - 1
    while(scalar_list[i] != 1):
        i = i - 1
    while i != 0:
        if(scalar_list[i] == 1):
            r0_point = point_addition(curve_constants_field, r0_point, r1_point, prime)
            r1_point = point_doubling(curve_constants_field, r1_point, prime)
        else:
            r1_point = point_addition(curve_constants_field, r0_point, r1_point, prime)
            r0_point = point_doubling(curve_constants_field, r0_point, prime)
        i = i - 1 

    if(scalar_list[i] == 1):
        r0_point = point_addition(curve_constants_field, r0_point, r1_point, prime)
        r1_point = point_doubling(curve_constants_field, r1_point, prime)
    else:
        r1_point = point_addition(curve_constants_field, r0_point, r1_point, prime)
        r0_point = point_doubling(curve_constants_field, r0_point, prime)    
    
    return r0_point
    

##
# curve_parameters[0] = name                    # Curve name (String)
# curve_parameters[1] = prime                   # Curve prime (Integer)
# curve_parameters[2] = order                   # Curve order (Integer)
# curve_parameters[3] = shape                   # Curve shape (String)                                                 
# curve_parameters[4] = arithmetic_parameters   # Arithmetic parameters for this curve (List)
# curve_parameters[5] = curve_constants         # Internal curve constants (List)
# curve_parameters[6] = swei_curve_constants    # Short Weierstrass curve constants (List)
# curve_parameters[7] = coordinate_system       # Point generator and infinity and coordinate formulas (List)
# curve_parameters[8] = swei_point_conversion   # Converts internal point to Short Weierstrass form (function)
##

##
# curve_constants[i] =                          # Curve constant (Integer)
##

## Coordinates system
# coordinate_system[0] =                        # Coordinate system name
# coordinate_system[1] =                        # Point Generator (List)
# coordinate_system[2] =                        # Point Infinity (List)
# coordinate_system[3] =                        # Convert affine to this system (function)
# coordinate_system[4] =                        # This system to affine (function)
# coordinate_system[5] =                        # Addition Formula (function)
# coordinate_system[6] =                        # Doubling Formula (function)
##    

def generate_random_value_hw(lowerHWLimit, upperHWLimit, totalSize):
    hw = randint(lowerHWLimit, upperHWLimit)
    onesList = [1]*hw
    zerosList = [0]*(totalSize-hw)
    totalList = onesList + zerosList
    randomList = []
    while(len(totalList) > 1):
        i = randint(0, len(totalList) - 1)
        randomList.append(totalList[i])
        totalList[i] = totalList[-1]
        totalList.pop()
    randomList.append(totalList[0])
    randomValue = list_to_integer(1, len(randomList), randomList)
    return randomValue

def generate_random_point_weierstrass_curve(curve_parameters):
    prime = curve_parameters[1]
    a = curve_parameters[5][0]
    b = curve_parameters[5][1]
    y0 = 0
    y1 = 0
    z = 1
    while(y0 == 0):
        x = randint(1, prime - 1)
        equation = (pow(x, 3, prime) + ((a*x) % prime) + b) % prime
        y0, y1 = square_root(equation, prime)
    whichY = randint(0, 1)
    if(whichY == 1):
        return x, y1, z
    else:
        return x, y0, z

def generate_x_through_y(y, curve_parameters):
    prime = curve_parameters[1]
    a = curve_parameters[5][0]
    b = curve_parameters[5][1]
    inverse_4 = pow(4, prime - 2, prime)
    inverse_27 = pow(27, prime - 2, prime)
    inverse_2 = pow(2, prime - 2, prime)
    cardano_p = a
    cardano_q = (b - (y*y % prime) ) % prime
    cardano_pre = ((cardano_q*cardano_q % prime)*inverse_4 + (cardano_p*cardano_p*cardano_p % prime)*inverse_27 ) % prime
    cardano_pre0, cardano_pre1 = square_root(cardano_pre, prime)
    if(cardano_pre0 == 0):
        return 0
    cardano_v3 = cardano_u3 = (prime - (cardano_q*inverse_2 % prime))
    cardano_u3 = (cardano_u3 + cardano_pre0) % prime
    cardano_v3 = (cardano_v3 + prime - cardano_pre0) % prime
    cardano_u = cube_root(cardano_u3, prime)
    cardano_v = cube_root(cardano_v3, prime)
    x = (cardano_u + cardano_v) % prime
    if(x != 0):
        return x
    if(cardano_pre1 == 0):
        return 0
    cardano_v3 = cardano_u3 = (prime - (cardano_q*inverse_2 % prime))
    cardano_u3 = (cardano_u3 + cardano_pre1) % prime
    cardano_v3 = (cardano_v3 + prime - cardano_pre1) % prime
    cardano_u = cube_root(cardano_u3, prime)
    cardano_v = cube_root(cardano_v3, prime)
    x = (cardano_u + cardano_v) % prime
    return x
        
def generate_random_point_weierstrass_curve_through_y(curve_parameters):
    prime = curve_parameters[1]
    a = curve_parameters[5][0]
    b = curve_parameters[5][1]
    x = 0
    y = 0
    z = 1
    while(x == 0):
        y = randint(2, prime - 1)
        x = generate_x_through_y(y, curve_parameters)
    return x, y, z

def generate_special_y_point_weierstrass_curve(curve_parameters, isNegative, lowerLimit=2, upperLimit=1024):
    prime = curve_parameters[1]
    a = curve_parameters[5][0]
    b = curve_parameters[5][1]
    x = 0
    y = 0
    z = 1
    inverse_4 = pow(4, prime - 2, prime)
    inverse_27 = pow(27, prime - 2, prime)
    inverse_2 = pow(2, prime - 2, prime)
    while(x == 0):
        y = randint(lowerLimit, upperLimit)
        if(isNegative):
            y = prime - y
        x = generate_x_through_y(y, curve_parameters)
    return x, y, z
    
def generate_hw_y_point_weierstrass_curve(curve_parameters, lowerHWLimit, upperHWLimit):
    prime = curve_parameters[1]
    a = curve_parameters[5][0]
    b = curve_parameters[5][1]
    x = 0
    y = 0
    z = 1
    while(x == 0):
        y = generate_random_value_hw(lowerHWLimit, upperHWLimit, prime.bit_length())
        x = generate_x_through_y(y, curve_parameters)
    return x, y, z  
        
def generate_special_x_point_weierstrass_curve(curve_parameters, isNegative, lowerLimit=2, upperLimit=1024):
    prime = curve_parameters[1]
    a = curve_parameters[5][0]
    b = curve_parameters[5][1]
    y0 = 0
    y1 = 0
    z = 1
    while(y0 == 0):
        x = randint(lowerLimit, upperLimit)
        if(isNegative):
            x = prime - x
        equation = (pow(x, 3, prime) + ((a*x) % prime) + b) % prime
        y0, y1 = square_root(equation, prime)
    if(y0 > y1):
        return x, y1, z
    else:
        return x, y0, z  
        
def generate_hw_x_point_weierstrass_curve(curve_parameters, lowerHWLimit, upperHWLimit):
    prime = curve_parameters[1]
    a = curve_parameters[5][0]
    b = curve_parameters[5][1]
    y0 = 0
    y1 = 0
    z = 1
    while(y0 == 0):
        x = generate_random_value_hw(lowerHWLimit, upperHWLimit, prime.bit_length())
        equation = (pow(x, 3, prime) + ((a*x) % prime) + b) % prime
        y0, y1 = square_root(equation, prime)
    if(y0 > y1):
        return x, y1, z
    else:
        return x, y0, z  
        
        
def apply_random_z_countermesure(curve_parameters, point, newZ=0):
    prime = curve_parameters[1]
    a = curve_parameters[5][0]
    b = curve_parameters[5][1]
    if(newZ == 0):
        newZ = randint(1, prime - 1)
    newX = (point[0] * newZ) % prime
    newY = (point[1] * newZ) % prime
    return newX, newY, newZ
        
def generate_random_tests(testGroupIdentifiers, numberOfIterations):
    sourceGroup = numberOfIterations*testGroupIdentifiers
    randomGroup = []
    while(len(sourceGroup) > 1):
        i = randint(0, len(sourceGroup) - 1)
        randomGroup.append(sourceGroup[i])
        sourceGroup[i] = sourceGroup[-1]
        sourceGroup.pop()
    randomGroup.append(sourceGroup[0])
    return randomGroup
    
curve_parameters = [
#
# Curve NIST P-256, secp256r1
# Curve name
("NIST_P256",
# Curve prime
2**256 - 2**224 + 2**192 + 2**96 - 1,
# Curve order
115792089210356248762697446949407573529996955224135760342422259061068512044369,
# Curve shape
"swei",
# Finite field
0,
#
# Curve Constants 
[
# Parameter a for Short Weierstrass shape
2**256 - 2**224 + 2**192 + 2**96 - 1 - 3,
# Parameter b for Short Weierstrass shape
41058363725152142129326129780047268409114441015993725554835256314039467401291,
],
# Curve Constants in Short Weierstrass
[],
#
# Coordinates system
[ 
"Homogeneous",
# Generator point
(
# x0 for base point in Short Weierstrass shape
48439561293906451759052585252797914202762949526041747995844080717082404635286,
# y0 for base point in Short Weierstrass shape
36134250956749795798585127919587881956611106672985015071877198253568414405109,
1,
),
# Infinity point
(
# x0 for base point in Short Weierstrass shape
0,
# y0 for base point in Short Weierstrass shape
1,
0,
),
(),
(),
short_weierstrass_point_addition_complete_a_m3_1,
short_weierstrass_point_doubling_complete_a_m3_1,
]
)
]

nele_point = [
# X
0xA1C4F0703C7253CAA91F40BF5C73AE51D9FB93839247A1785EEF8620AF268EE1,
# Y
0x6C9B4467424BD388A861B08CA915463BE529521A0987B8C241C43316BD89C4D6,
# Z
1
]

scalar = [
0xE0B74E5109721A8EF7212ED6ACF005CC9C542A73D89CDF6229C4BDDFDC30061D,
0xe1b7f07df64f3b71f57dce2aef054bffe7ca02202f7845cd3f213208fb3a6d18,
]

computingPoint = [0,0,0] 

prime = curve_parameters[0][1]

numberOfIterations = 0
testGroupIdentifiers = [0, 1, 2, 31, 13, 32, 23, 35, 53, 36, 63, 41, 42]
parameter = 1
baseTraceFileName = ""
loadLecroyPanelEnabled = False
lecroyPanelFileName = ""
wordFormat = 1
wordFormatName = 'i'
numberOfPointsTrace = 1000000000
baseIterationNumber = 0
enableZCountermesure = False

numberOfParameters = len(sys.argv)

if(numberOfParameters < 5):
    print "To use this program you have to specify the following"
    print
    print 'test_ecp.py -i numberOfIterations -t baseTraceFileName [options]'
    print
    print '-i numberOfIterations you specify the number of aquisitions per group, it needs to be higher than 1'
    print
    print '-t baseTraceFileName you specify the base trace file to be used'
    print
    print '[options]:'
    print
    print '-g "f"|"k"|"p"|"s"|"x"'
    print 'Specifies the tests types to be done. They can be:'
    print 'f (fixed scalar and Point)    k (random scalar)    p (random Point)    x (special scalar)    s(special Point)'
    print 'or the combination of such tests'
    print 'the default is the fkpsx, where all 5 tests are performed'
    print
    print '-l lecroyPanelFileName'
    print 'Specify Lecroy Panel file name to load, otherwise it will just leave the seetings that are in effect'
    print
    print '-d b|i|f'
    print 'If you want the data in byte format (b), 2 bytes format (i) or float format(f). If not specified the default is 2 bytes format (i).'
    print
    print '-p numberOfTracePoints'
    print 'Specify the number of points that you need for each trace.'
    print 'This number is not the number that is measured in the osciloscope, but instead transfered to the computer.'
    print 'If not specified it is assumed 1000000000, which is probably big enough to ask for all'
    print
    print '-j startIterationFile'
    print 'Input the number of iteration to start, this way it is possible to acquire traces separatly.'
    print 'By default the program starts with iteration 0.'
    print 
    print '-z'
    print 'Enable the z-coordinate countermeasure.'
    print 'The default is without countermesure.'
    sys.exit()
    


while(numberOfParameters > 1):
    if(sys.argv[parameter] == '-i'):
        parameter += 1
        numberOfIterations = int(sys.argv[parameter])
        parameter += 1
        numberOfParameters -= 2
    elif(sys.argv[parameter] == '-t'):
        parameter += 1
        baseTraceFileName = str(sys.argv[parameter])
        parameter += 1
        numberOfParameters -= 2
    elif(sys.argv[parameter] == '-g'):
        parameter += 1
        testsTypes = sys.argv[parameter]
        testGroupIdentifiers = []
        for testType in testsTypes:
            if(testType == 'f'):
                testGroupIdentifiers += [0]
            elif(testType == 'k'):
                testGroupIdentifiers += [1]
            elif(testType == 'p'):
                testGroupIdentifiers += [2]
            elif(testType == 's'):
                testGroupIdentifiers += [31,13,32,23,35,53,36,63]
            elif(testType == 'x'):
                testGroupIdentifiers += [41,42]
            else:
                print 'Not recognized parameter : ' + testType
        parameter += 1
        numberOfParameters -= 2
    elif(sys.argv[parameter] == '-l'):
        parameter += 1
        lecroyPanelFileName = str(sys.argv[parameter])
        parameter += 1
        numberOfParameters -= 2
        loadLecroyPanelEnabled = True
    elif(sys.argv[parameter] == '-d'):
        parameter += 1
        if(sys.argv[parameter] == 'b'):
            wordFormat = 0
            wordFormatName = 'b'
        elif(sys.argv[parameter] == 'i'):
            wordFormat = 1
            wordFormatName = 'i'
        elif(sys.argv[parameter] == 'f'):
            wordFormat = 2
            wordFormatName = 'f'
        else:
            print 'Not recognized parameter : ' + sys.argv[parameter]
        parameter += 1
        numberOfParameters -= 2
    elif(sys.argv[parameter] == '-p'):
        parameter += 1
        numberOfPointsTrace = int(sys.argv[parameter])
        parameter += 1
        numberOfParameters -= 2
    elif(sys.argv[parameter] == '-j'):
        parameter += 1
        baseIterationNumber = int(sys.argv[parameter])
        parameter += 1
        numberOfParameters -= 2
    elif(sys.argv[parameter] == '-z'):
        parameter += 1
        enableZCountermesure = True
        numberOfParameters -= 1
    else:
        parameter += 1
        numberOfParameters -= 1

allGroupTests = generate_random_tests(testGroupIdentifiers, numberOfIterations)
        
le = Lecroy()
le.connect()        
        
if(loadLecroyPanelEnabled):
    le.loadLecroyPanelFromFile(lecroyPanelFileName)

sakura = SASEBOGII()

print "Sakura connection succeeded ? " + str(sakura.connect())

computingScalar = scalar[0]

errorDuringComputation = False

le.setTriggerMode("NORM")

j = baseIterationNumber
i = 0
while(i < len(allGroupTests)):
    #le.armAndWaitLecroy()
    le.enableWaitLecroyAquistion()
    time.sleep(0.100) # It is necessary to sleep so the oscilloscope does not loose the trigger event1
    
    traceFileName = baseTraceFileName + '_' + wordFormatName + '_' + str(j)
    traceFile = open(traceFileName, "wb")
    
    if(DEBUG_MODE):
        print
        print "Group test to be performed : " + str(allGroupTests[i])
        print
    
    if(allGroupTests[i] == 1):
        computingScalar = randint(2**(prime.bit_length()-1), 2**(prime.bit_length())-1)
    else:
        computingScalar = scalar[0]

    if(allGroupTests[i] == 2):
        computingPoint[0], computingPoint[1], computingPoint[2] = generate_random_point_weierstrass_curve(curve_parameters[0])
    else:    
        computingPoint[0] = curve_parameters[0][7][1][0]
        computingPoint[1] = curve_parameters[0][7][1][1]
        computingPoint[2] = curve_parameters[0][7][1][2]
    
    if(allGroupTests[i] == 31):
        computingPoint[0], computingPoint[1], computingPoint[2] = generate_special_x_point_weierstrass_curve(curve_parameters[0], False, 2, 1024)
    elif(allGroupTests[i] == 13):
        computingPoint[0], computingPoint[1], computingPoint[2] = generate_special_y_point_weierstrass_curve(curve_parameters[0], False, 2, 1024)
    elif(allGroupTests[i] == 32):
        computingPoint[0], computingPoint[1], computingPoint[2] = generate_special_x_point_weierstrass_curve(curve_parameters[0], True, 2, 1024)
    elif(allGroupTests[i] == 23):
        computingPoint[0], computingPoint[1], computingPoint[2] = generate_special_y_point_weierstrass_curve(curve_parameters[0], True, 2, 1024)
    elif(allGroupTests[i] == 35):
        computingPoint[0], computingPoint[1], computingPoint[2] = generate_hw_x_point_weierstrass_curve(curve_parameters[0], 1, 25)
    elif(allGroupTests[i] == 53):
        computingPoint[0], computingPoint[1], computingPoint[2] = generate_hw_y_point_weierstrass_curve(curve_parameters[0], 1, 25)
    elif(allGroupTests[i] == 36):
        computingPoint[0], computingPoint[1], computingPoint[2] = generate_hw_x_point_weierstrass_curve(curve_parameters[0], 230, prime.bit_length())
    elif(allGroupTests[i] == 63):
        computingPoint[0], computingPoint[1], computingPoint[2] = generate_hw_y_point_weierstrass_curve(curve_parameters[0], 230, prime.bit_length())
    elif(allGroupTests[i] == 41):
        computingScalar = randint(2, 1024)
    elif(allGroupTests[i] == 42):
        computingScalar = 2**(prime.bit_length()) - 1 - randint(0, 1024)
    
    if(enableZCountermesure):
        randomZ = randint(1, prime - 1)
    else:
        randomZ = 1

    computingPointWithRandomZ = apply_random_z_countermesure(curve_parameters[0], computingPoint, randomZ)
        
    if(DEBUG_MODE):
        print "Writing new Point Coordinate x :"
        print hex(computingPointWithRandomZ[0])
        print "Writing new Point Coordinate y :"
        print hex(computingPointWithRandomZ[1])
        print "Writing new Scalar :"
        print hex(computingScalar)
        print "Writing new RandomZ :"
        print hex(randomZ)
        print

    sakura.writeOriginalPoint(computingPointWithRandomZ)
    sakura.writeScalar(computingScalar)
    sakura.writeOriginalRandomZ(randomZ)

    originalPoint = sakura.readOriginalPoint()
    originalScalar = sakura.readScalar()
    originalRandomZ = sakura.readOriginalRandomZ()
    if(DEBUG_MODE):
        print "Original Point Coordinate x : "
        print hex(originalPoint[0])
        print "Original Point Coordinate y : "
        print hex(originalPoint[1])
        print "Original Scalar : "
        print hex(originalScalar)
        print "Original RandomZ : "
        print hex(originalRandomZ)
        print

    if(originalPoint[0] != computingPointWithRandomZ[0]):
        print "Error during reading and writing coordinate x"
    if(originalPoint[1] != computingPointWithRandomZ[1]):
        print "Error during reading and writing coordinate y"
    if(originalScalar != computingScalar):
        print "Error during reading and writing scalar"
    if(randomZ != originalRandomZ):
        print "Error during reading and writing RandomZ"
    
    sakura.startComputation()
    
    finalComputedPoint = scalar_point_multiplication_2(curve_parameters[0], computingPointWithRandomZ, computingScalar)
    affineFinalComputedPoint = [0, 0, 0]
    inversionValue = pow(finalComputedPoint[2], prime - 2, prime)
    affineFinalComputedPoint[0]  = (finalComputedPoint[0] * inversionValue) % prime
    affineFinalComputedPoint[1]  = (finalComputedPoint[1] * inversionValue) % prime
    affineFinalComputedPoint[2]  = (finalComputedPoint[2] * inversionValue) % prime

    #time.sleep(0.100)
    
    while(not sakura.isFree()):
        time.sleep(0.100)
        #print "Not finished" 
    
    #time.sleep(0.300)
    le.waitLecroy()
    #le.stopLecroy()
    #le.waitLecroy()

    
    if(DEBUG_MODE):
        print "Computed Point Coordinate x : "
        print hex(affineFinalComputedPoint[0])
        print "Computed Point Coordinate y : "
        print hex(affineFinalComputedPoint[1])
        print

    finalSakuraPoint = sakura.readFinalPoint()
    if(DEBUG_MODE):
        print "Sakura Point Coordinate x : "
        print hex(finalSakuraPoint[0])
        print "Sakura Point Coordinate y : "
        print hex(finalSakuraPoint[1])
        print

    errorDuringComputation = False
    
    if(finalSakuraPoint[0] != affineFinalComputedPoint[0]):
        print "Error during computation or reading and writing coordinate X"
        errorDuringComputation = True
        traceFile.close()
        continue
    if(finalSakuraPoint[1] != affineFinalComputedPoint[1]):
        print "Error during computation or reading and writing coordinate Y"
        errorDuringComputation = True
        traceFile.close()
        continue
        
    #time.sleep(1)
    
    
    if(wordFormat == 0):
        c2_out, c2_out_proper = le.getNativeSignalBytes('C2', numberOfPointsTrace, False, 3)
        voltageGain, voltageOffset, timeInterval, timeOffset = le.getWaveformDescryption("C2", False)
    elif(wordFormat == 1):
        c2_out, c2_out_proper = le.getNativeSignalBytes('C2', numberOfPointsTrace, True, 3)
        voltageGain, voltageOffset, timeInterval, timeOffset = le.getWaveformDescryption("C2", True)
    elif(wordFormat == 2):
        c2_out, c2_out_proper = le.getNativeSignalFloat('C2', numberOfPointsTrace, 0, False)
    print len(c2_out)
    if(SHOW_GRAPH):
        stepFactor = 1000
        c2_out_proper_applied = c2_out_proper[::stepFactor]
        y_float_value = [(c2_out_proper_applied[z]*voltageGain*stepFactor - voltageOffset) for z in range(len(c2_out_proper_applied))]
        x_float_value = [(timeInterval*z*stepFactor + timeOffset) for z in range(len(c2_out_proper_applied))]
        plt.plot(x_float_value, y_float_value)
        plt.show()
    
    sys.stdout.flush()
    bufferWrite = struct.pack("b", allGroupTests[i])
    bufferWrite += integer_to_writable_string(computingPoint[0], 256)
    bufferWrite += integer_to_writable_string(computingPoint[1], 256)
    bufferWrite += integer_to_writable_string(computingScalar, 256)
    bufferWrite += integer_to_writable_string(affineFinalComputedPoint[0], 256)
    bufferWrite += integer_to_writable_string(affineFinalComputedPoint[1], 256)
    if((wordFormat == 0) or (wordFormat == 1)):
        bufferWrite += struct.pack("4d", voltageGain, voltageOffset, timeInterval, timeOffset)
    bufferWrite += integer_to_writable_string(randomZ, 256)
    traceFile.write(bufferWrite)
    traceFile.write(c2_out)
    traceFile.close()
    
    print "Iteration number : " + str(i) + "  out of " + str(len(allGroupTests) - 1) + "  file number : " + str(j)
    
    while(not sakura.isFree()):
        time.sleep(0.100)
        #print "Not finished" 
    
    j = j + 1
    i = i + 1
le.disconnect()

