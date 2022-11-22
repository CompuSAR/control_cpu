# Linker script for Boot Loader stage 1
MEMORY { sram : ORIGIN = 0x80000000, LENGTH = 0x8000 }
MEMORY { discard : ORIGIN = 0x1000000, LENGTH = 0x1000000 }
MEMORY { error : ORIGIN = 0xf0000000, LENGTH = 0 }
MEMORY { ddr : ORIGIN = 0x0, LENGTH = 256*1024*1024 }
SECTIONS
{
    .text : {
        . = ALIGN(4);
        crt.o (.text*)
        * (.text*)
        . = ALIGN(4);
    } >sram
    .rodata : {
        . = ALIGN(4);
         *(.rodata*)
        . = ALIGN(4);
    } >sram

    .got : {
        . = ALIGN(4);
        *(.got)
        . = ALIGN(4);
    } > sram

    .got.plt : {
        . = ALIGN(4);
        *(.got.plt)
        . = ALIGN(4);
    } > sram

    /DISCARD/ : { *(.eh_frame) }

    .debug_info : { *(.debug_info) } >discard
    .debug_abbrev : { *(.debug_abbrev) } >discard
    .debug_loc : { *(.debug_loc) } >discard
    .debug_aranges : { *(.debug_aranges) } >discard
    .debug_line : { *(.debug_line) } >discard
    .debug_str : { *(.debug_str) } >discard
    .debug_ranges : { *(.debug_ranges) } >discard
    .debug_line_str : { *(.debug_line_str) } >discard
    .debug_loclists : { *(.debug_loclists) } >discard
    .debug_rnglists : { *(.debug_rnglists) } >discard
    .riscv.attributes : { *(.riscv.attributes) } >discard
    .comment : { *(.comment) } >discard

    PROVIDE(DDR_MEMORY = 0);
    .unknown : { *(.*) } >error
}
