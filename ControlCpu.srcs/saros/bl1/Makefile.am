ARCH=-march=rv32i
ABI=-mabi=ilp32

AM_CCASFLAGS=$(ARCH) $(ABI) -nostdlib
AM_CXXFLAGS=$(ARCH) $(ABI) -nostdlib
AM_CFLAGS=$(ARCH) $(ABI) -nostdlib

noinst_PROGRAMS=bl1.elf

REMOVED_SECTIONS=debug_* riscv.attribute comment

%.coe: %.raw
	sed -e '$$s:,:;:' "$<" > "$@".tmp
	mv "$@".tmp "$@"

%.raw: %.bin
	echo -e 'memory_initialization_radix = 16;\nmemory_initialization_vector =' > "$@".tmp
	hexdump -e '1/4 "  %08x" ",\n"' "$<" >> "$@".tmp
	mv "$@".tmp "$@"

bl1.mem: bl1.bin
	hexdump -e '1/4 "%08x" "\n"' "$<" > "$@".tmp
	mv "$@".tmp "$@"

bl1.bin: bl1.elf
	$(HOST_TRIPLET)-objcopy -O binary "$<" "$@" $(foreach rem,$(REMOVED_SECTIONS), --remove-section="$(rem)")

bl1_elf_SOURCES=crt.s bl1_start.cpp uart.cpp
EXTRA_bl1_elf_DEPENDENCIES=$(srcdir)/bl1.lds
bl1_elf_LDFLAGS=-T $(srcdir)/bl1.lds

bl1.elf$(EXEEXT): $(bl1_elf_OBJECTS) $(EXTRA_bl1_elf_DEPENDENCIES)
	$(HOST_TRIPLET)-ld $(LDFLAGS) $(AM_LDFLAGS) $(bl1_elf_LDFLAGS) -melf32lriscv_ilp32 $(bl1_elf_OBJECTS) -o "$@"

clean-local:
	$(RM) *.mem *.coe *.bin *.raw
