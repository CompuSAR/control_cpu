#include "uart.h"

extern "C" void bl1_start();

extern unsigned int DDR_MEMORY[256*1024*1024/4];

void bl1_start() {
    DDR_MEMORY[0] = 12;
    uart_send("Hello, world\n");
    if( DDR_MEMORY[0]==12 )
        uart_send("Verified\n");
    else
        uart_send("Verification failed\n");

    while(true)
        ;
}
