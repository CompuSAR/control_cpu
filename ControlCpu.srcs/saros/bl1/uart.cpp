#include "uart.h"

#include "gpio.h"

static volatile unsigned long *uart = reinterpret_cast<unsigned long *>(0xc000'0000);

void uart_send(char c) {
    if( read_gpio(0)&1 )
        *uart = static_cast<unsigned long>(c) & 0xff;
}

void uart_send(const char *str) {
    if( read_gpio(0)&1 ) {
        while( *str != '\0' ) {
            uart_send(*str);
            ++str;
        }
    }
}
