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

    .data : {
        . = ALIGN(4);
         *(.data*)
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

    .debug_info : { *(.debug_info) }
    .debug_abbrev : { *(.debug_abbrev) }
    .debug_loc : { *(.debug_loc) }
    .debug_aranges : { *(.debug_aranges) }
    .debug_line : { *(.debug_line) }
    .debug_str : { *(.debug_str) }
    .debug_ranges : { *(.debug_ranges) }
    .debug_line_str : { *(.debug_line_str) }
    .debug_loclists : { *(.debug_loclists) }
    .debug_rnglists : { *(.debug_rnglists) }
    .debug_frame : { *(.debug_frame) }
    .riscv.attributes : { *(.riscv.attributes) } >discard
    .comment : { *(.comment) } >discard

    PROVIDE(DDR_MEMORY = 0);
    .unknown : { *(.*) } >error
}
