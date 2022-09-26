# Linker script for Boot Loader stage 1
MEMORY { .sram : ORIGIN = 0x0000, LENGTH = 0x8000 }
MEMORY { .discard : ORIGIN = 0x1000000, LENGTH = 0x1000000 }
MEMORY { .error : ORIGIN = 0x80000000, LENGTH = 0 }
SECTIONS
{
    .text : {
        crt.o (.text*)
        * (.text*)
    } >.sram

    /DISCARD/ : { *(.eh_frame) }

    .debug_info : { *(.debug_info) } >.discard
    .debug_abbrev : { *(.debug_abbrev) } >.discard
    .debug_loc : { *(.debug_loc) } >.discard
    .debug_aranges : { *(.debug_aranges) } >.discard
    .debug_line : { *(.debug_line) } >.discard
    .debug_str : { *(.debug_str) } >.discard
    .debug_ranges : { *(.debug_ranges) } >.discard
    .debug_line_str : { *(.debug_line_str) } >.discard
    .riscv.attributes : { *(.riscv.attribute) } >.discard
    .comment : { *(.comment) } >.discard

    .unkonwn : { *(.unknown) } > .error
}
