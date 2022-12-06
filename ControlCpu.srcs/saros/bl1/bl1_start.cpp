#include "uart.h"
#include "format.h"
#include "ddr.h"

extern "C" void bl1_start();

extern volatile unsigned int DDR_MEMORY[256*1024*1024/4];

unsigned int test_buffer[] = {
    0x70befbfb,
    0xe4be39ff,
    0xcd58d3be
};

void bl1_start() {
    ddr_init();

    DDR_MEMORY[16]=0x75c8f355;
    uart_send('.');
    DDR_MEMORY[32]=0x252505f5;
    uint32_t mem = DDR_MEMORY[16];
    print_hex(mem);
    uart_send('.');

    mem = DDR_MEMORY[32];
    print_hex(mem);
    uart_send('\n');

    mem = DDR_MEMORY[16];
    print_hex(mem);
    uart_send('\n');

    uart_send("Hello, world\n");
    mem = DDR_MEMORY[15];
    print_hex(mem);
    uart_send('\n');

    mem = DDR_MEMORY[32];
    print_hex(mem);
    uart_send('\n');

    DDR_MEMORY[0] = 12;
    mem = DDR_MEMORY[16];
    print_hex(mem);

    uart_send("\nWorld's still here\n");

    mem = DDR_MEMORY[16];
    print_hex(mem);
    uart_send('\n');

    mem = DDR_MEMORY[32];
    print_hex(mem);
    uart_send('\n');

    if( DDR_MEMORY[0]==12 )
        uart_send("Verified\n");
    else {
        uart_send("Verification failed\n");
        print_hex(DDR_MEMORY[1]);
        uart_send('\n');
    }

    while(true)
        ;
}
