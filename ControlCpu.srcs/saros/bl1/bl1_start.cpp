#include "ddr.h"
#include "elf_reader.h"
#include "format.h"
#include "irq.h"
#include "spi.h"
#include "spi_flash.h"
#include "uart.h"

extern "C" void bl1_start();

static constexpr unsigned int FIBONACCI_COEF = 0x9E3779B9;
static constexpr unsigned int RANDOM_WALK_COEF = 0x26fcb789;

static constexpr unsigned int MEMORY_SIZE=(256*1024*1024 - 32*1024)/4;
extern unsigned int DDR_MEMORY[MEMORY_SIZE];

extern uint32_t BSS_START[], BSS_END;

void hex_dump(const void *mem, size_t size) {
    const uint8_t *translated = reinterpret_cast<const uint8_t *>(mem);
    for(size_t i=0; i<size; ++i) {
        uart_send(" ");
        print_hex(translated[i]);
    }
}

void bl1_start() {
    for( uint32_t *bss = BSS_START; bss < &BSS_END; ++bss )
        *bss = 0;

    uart_send("\nInitializing memory\n");
    ddr_init();

    uart_send("Memory initialized. Initializing SPI flash\n");

    SPI_FLASH::init_flash();

    ElfReader::EntryPoint second_stage = ElfReader::load_os();

    uart_send("OS loaded with entry point ");
    print_hex(reinterpret_cast<uint32_t>(second_stage));
    uart_send("\n");

    second_stage();

    uart_send("Second stage code unexpectedly returned\n");

    halt();
}
