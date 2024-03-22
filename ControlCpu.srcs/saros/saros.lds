# Linker script for Boot Loader stage 1
MEMORY { preload(rwx) : ORIGIN = 0x80000000, LENGTH = 0x8000 }
MEMORY { discard : ORIGIN = 0x1000000, LENGTH = 0x1000000 }
MEMORY { error : ORIGIN = 0xf0000000, LENGTH = 0 }
MEMORY { exe(rx) : ORIGIN = 0x80100000, LENGTH = 0x100000 }
MEMORY { readonly(r) : ORIGIN = 0x80200000, LENGTH = 0x100000 }
MEMORY { ram(rw) : ORIGIN = 0x80300000, LENGTH = 256*1024*1024 - 0x300000 }
ENTRY(_start)
SECTIONS
{
    .text : {
        . = ALIGN(4);
        * (.text.startup)
        . = ALIGN(4);
        * (.text*)
        . = ALIGN(4);
    } >exe
    .init_array : {
        . = ALIGN(4);
        * (.init_array)
    } >ram
    .fini_array : {
        . = ALIGN(4);
        * (.fini_array)
    } >ram
    .rodata : {
        . = ALIGN(4);
        *(.rodata*)
        . = ALIGN(4);
    } >readonly

    .got : {
        . = ALIGN(4);
        *(.got)
        . = ALIGN(4);
    } >readonly

    .got.plt : {
        . = ALIGN(4);
        *(.got.plt)
        . = ALIGN(4);
    } >readonly

    .data : {
        . = ALIGN(4);
         *(.data*)
        . = ALIGN(4);
    } >ram

    .sdata : {
        . = ALIGN(4);
         *(.sdata*)
        . = ALIGN(4);
    } >ram

    .bss : {
        . = ALIGN(32);
        * (.bss*)
        . = ALIGN(32);
        * (.sbss*)
        . = ALIGN(32);
    } >ram

    PROVIDE(HEAP_START = .);

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

    .unknown : { *(.*) } >error
}
