# Linker script for Boot Loader stage 1
MEMORY { preload : ORIGIN = 0x80000000, LENGTH = 0x8000 }
MEMORY { discard : ORIGIN = 0x1000000, LENGTH = 0x1000000 }
MEMORY { error : ORIGIN = 0xf0000000, LENGTH = 0 }
MEMORY { ddr : ORIGIN = 0x80008000, LENGTH = 256*1024*1024 - 0x8000 }
SECTIONS
{
    .text : {
        . = ALIGN(4);
        crt.o (.text*)
        * (.text*)
        . = ALIGN(4);
    } >preload
    .rodata : {
        . = ALIGN(4);
         *(.rodata*)
        . = ALIGN(4);
    } >preload

    .data : {
        . = ALIGN(4);
         *(.data*)
        . = ALIGN(4);
    } >preload

    .sdata : {
        . = ALIGN(4);
         *(.sdata*)
        . = ALIGN(4);
    } >preload

    .got : {
        . = ALIGN(4);
        *(.got)
        . = ALIGN(4);
    } > preload

    .got.plt : {
        . = ALIGN(4);
        *(.got.plt)
        . = ALIGN(4);
    } > preload

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

    PROVIDE(DDR_MEMORY = 0x80008000);
    .unknown : { *(.*) } >error
}
