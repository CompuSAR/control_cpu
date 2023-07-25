#include "ddr.h"
#include "format.h"
#include "irq.h"
#include "spi.h"
#include "spi_flash.h"
#include "uart.h"

extern "C" void bl1_start();

static constexpr unsigned int FIBONACCI_COEF = 0x9E3779B9;
static constexpr unsigned int RANDOM_WALK_COEF = 0x26fcb789;

static constexpr unsigned int MEMORY_SIZE=(256*1024*1024 - 32*1024)/4;
extern volatile unsigned int DDR_MEMORY[MEMORY_SIZE];

extern uint32_t BSS_START[], BSS_END;

void bl1_start() {
    for( uint32_t *bss = BSS_START; bss < &BSS_END; ++bss )
        *bss = 0;

    uart_send("\nInitializing memory\n");
    ddr_init();

    uart_send("Memory initialized. Initializing SPI flash\n");

    SPI_FLASH::init_flash();

    uart_send("Halting\n");
    halt();

    uart_send("Post halt code reached\n");
}
