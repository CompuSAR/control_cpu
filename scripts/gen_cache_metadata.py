#!/usr/bin/python3

import sys

address_bits = int(sys.argv[2])
val = int(sys.argv[3]) # address
val |= 3<<address_bits
strval = format(val, "x")

initialized_length = int(sys.argv[1])
total_length = int(sys.argv[4])
for i in range(initialized_length):
    print(strval)

for i in range(total_length-initialized_length):
    print(len(strval)*"0")
