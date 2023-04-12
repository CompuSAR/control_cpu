#!/usr/bin/python3

import sys

address_bits = int(sys.argv[2])

val = int(sys.argv[3]) # address
val |= 3<<address_bits # valid and dirty
strval = format(val, "x")

initialized_length = int(sys.argv[1])
total_length = int(sys.argv[4])
for i in range(initialized_length):
    print(strval)

val = int(sys.argv[3]) # address
val |= 2<<address_bits # valid and clean
strval = format(val, "x")

for i in range(total_length-initialized_length):
    print(strval)
