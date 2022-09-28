#include "uart.h"

extern "C" void bl1_start();

void bl1_start() {
    uart_send("Hello, world\n");

    while(true)
        ;
}
