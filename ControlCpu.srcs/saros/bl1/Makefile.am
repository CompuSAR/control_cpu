#HOST_TRIPLET=riscv64-linux-gnu-
#AS=$(HOST_TRIPLET)as
#CC=$(HOST_TRIPLET)gcc
#CXX=$(HOST_TRIPLET)g++
#LD=$(HOST_TRIPLET)ld

#ARCH=-march=rv32i
#ABI=-mabi=ilp32

#override ASFLAGS+= $(ARCH) $(ABI)
#override CFLAGS+= $(ARCH) $(ABI)
#override CXXFLAGS+= $(ARCH) $(ABI)

noinst_PROGRAMS=bl1.elf

bl1.bin: bl1.elf
	$(HOST_TRIPLET)objcopy -Obin "$<" "$@"

bl1_elf_SOURCES=crt.s bl1_start.cpp

#bl1.elf: crt.o bl1_start.o
#	$(LD) $(LDFLAGS) -melf32lriscv_ilp32 $^ -o "$@" -T

