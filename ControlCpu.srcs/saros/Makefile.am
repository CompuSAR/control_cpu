SUBDIRS=bl1

ARCH=-march=rv32i
ABI=-mabi=ilp32

AM_CCASFLAGS=$(ARCH) $(ABI)
AM_CXXFLAGS=$(ARCH) $(ABI)
AM_CFLAGS=$(ARCH) $(ABI)
AM_CPPFLAGS=-I$(top_srcdir)/include -DSAROS

noinst_PROGRAMS=saros.elf

REMOVED_SECTIONS=
TOOLCHAIN_PATH=/opt/riscv
TOOLCHAIN_LIB_PATH=$(TOOLCHAIN_PATH)/lib/gcc/$(HOST_TRIPLET)/12.2.0
SCRIPTS_PATH=$(top_srcdir)/../../scripts

saros_elf_SOURCES=saros/start.cpp saros/uart.cpp common/format.cpp saros/irq.cpp common/reg.cpp common/gpio.cpp saros/irq_wrapper.s
EXTRA_saros_elf_DEPENDENCIES=$(srcdir)/saros.lds
saros_elf_LDFLAGS=-T $(srcdir)/saros.lds
saros_elf_LDADD=$(TOOLCHAIN_LIB_PATH)/libgcc.a $(TOOLCHAIN_PATH)/$(HOST_TRIPLET)/lib/libc.a

saros.elf$(EXEEXT): $(saros_elf_OBJECTS) $(EXTRA_saros_elf_DEPENDENCIES)
	$(HOST_TRIPLET)-ld $(LDFLAGS) $(AM_LDFLAGS) $(saros_elf_LDFLAGS) -melf32lriscv $(saros_elf_OBJECTS) -o "$@" $(saros_elf_LDADD)

saros.bin: saros.elf$(EXEEXT)
	cp $< $@.tmp
	$(HOST_TRIPLET)-strip $@.tmp
	mv $@.tmp $@

saros.mcs: saros.bin
	$(SCRIPTS_PATH)/make_hex.py "" "$<" > "$@".tmp
	mv "$@".tmp "$@"

saros.mem: saros.bin
	echo "@200000" > "$@.tmp"
	hexdump -ve '16/1 "%02X " "\n"' "$<" >> "$@.tmp"
	mv "$@.tmp" "$@"
