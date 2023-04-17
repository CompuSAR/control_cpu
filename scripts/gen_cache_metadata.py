#!/usr/bin/python3

# Arguments
# 1 - number of initialized cachelines. This need to be marked "dirty"
# 2 - number of complementing address bits.
# 3 - initial complementing address bits in cachelines
# 4 - Number of cachelines
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
