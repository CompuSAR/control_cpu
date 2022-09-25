; Linker script for Boot Loader stage 1
MEMORY { .sram : ORIGIN = 0x0000, LENGTH = 0x8000 }
SECTIONS
{
    .text : {
        crt.o (.text*)
        * (.text*)
    } >.sram
}
