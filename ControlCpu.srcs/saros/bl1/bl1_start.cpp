#include "uart.h"
#include "format.h"

extern "C" void bl1_start();

extern volatile unsigned int DDR_MEMORY[256*1024*1024/4];

void bl1_start() {
    uint32_t mem = DDR_MEMORY[0];
    print_hex(mem);
    uart_send('\n');

    mem = DDR_MEMORY[1];
    print_hex(mem);
    uart_send('\n');

    uart_send("Hello, world\n");
    mem = DDR_MEMORY[0];
    print_hex(mem);
    uart_send('\n');

    mem = DDR_MEMORY[1];
    print_hex(mem);
    uart_send('\n');

    DDR_MEMORY[0] = 12;
    mem = DDR_MEMORY[0];
    print_hex(mem);

    uart_send("\nWorld's still here\n");

    mem = DDR_MEMORY[0];
    print_hex(mem);
    uart_send('\n');

    mem = DDR_MEMORY[1];
    print_hex(mem);
    uart_send('\n');

    if( DDR_MEMORY[0]==12 )
        uart_send("Verified\n");
    else {
        uart_send("Verification failed\n");
        print_hex(DDR_MEMORY[0]);
        uart_send('\n');
    }

    while(true)
        ;
}
