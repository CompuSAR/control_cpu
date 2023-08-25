#include "uart.h"
#include "irq.h"

extern unsigned char HEAP_START[];

extern "C"
int _start() {
    uart_send("Second stage!");

    halt();
}
