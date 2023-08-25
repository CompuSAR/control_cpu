#!/usr/bin/python3

import argparse
import sys

class HexLine:
    def __init__(self, output):
        self._ext = 0
        self._out = output

    def write( self, addr : int, data ):
        if addr>>16 != self._ext:
            ext = addr>>16
            self._write(4, 0, [(ext>>8) & 0xff, ext&0xff])

            self._ext = ext

        addr &= 0xffff

        self._write(0, addr, data)


    def end(self):
        self._write(1, 0, [])



    def _write( self, cmd, addr, data ):
        res = ":"

        data = bytearray(data)

        length = len(data)
        assert length<=16
        sum = length
        res += f"{length:02X}"

        sum += addr>>8
        sum += addr&0xff
        res += f"{addr:04X}"

        sum += cmd
        res += f"{cmd:02X}"

        for datum in data:
            sum += datum
            res += f"{datum:02X}"

        # Calculate checksum
        sum &= 0xff
        sum = 0x100 - sum
        sum &= 0xff
        res += f"{sum:02X}"

        print(res, file=self._out)



parser = argparse.ArgumentParser(
        prog='makehex',
        description='Create Intel HEX files')

parser.add_argument('FPGA_design')
parser.add_argument('OS_image', type=argparse.FileType('rb'))
parser.add_argument('-o', '--output', action='store', type=argparse.FileType('w'), default=sys.stdout)
parser.add_argument('--offset', action='store', default=2*1024*1024)

args = parser.parse_args()

if args.FPGA_design:
    print("Including the FPGA design is not supported yet", file=sys.stderr)
    sys.exit(1)

addr = args.offset

line = HexLine(args.output)

while d := args.OS_image.read(16):
    line.write(addr, d)
    addr += len(d)

line.end()
