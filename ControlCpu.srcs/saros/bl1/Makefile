HOST_TRIPLET=riscv64-linux-gnu-
AS=$(HOST_TRIPLET)as
CC=$(HOST_TRIPLET)gcc
CXX=$(HOST_TRIPLET)g++
LD=$(HOST_TRIPLET)ld

ARCH=-march=rv32i
ABI=-mabi=ilp32

override ASFLAGS+= $(ARCH) $(ABI)
override CFLAGS+= $(ARCH) $(ABI)
override CXXFLAGS+= $(ARCH) $(ABI)

bl1.bin: bl1.elf
	$(HOST_TRIPLET)objcopy -Obin "$<" "$@"

bl1.elf: crt.o bl1_start.o
	$(LD) $(LDFLAGS) -melf32lriscv_ilp32 $^ -o "$@"

clean:
	$(RM) 
.PHONY: clean
