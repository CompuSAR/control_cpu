#include "uart.h"

#include "irq.h"
#include "memory.h"
#include "reg.h"
#include "spsc.h"

#include <cstddef>
#include <cstdint>

static SPSC<char, 1024> charsQueue;

static constexpr uint32_t UART_DEVICE = 0;

static constexpr uint32_t UART_DATA_REG =       0x0000;
static constexpr uint32_t UART_STATUS_REG =     0x0004;
static constexpr uint32_t UART_STATUS_REG__READY = 0x00000001;

void uart_send_raw(char c) {
    reg_write_32( UART_DEVICE, UART_DATA_REG, c );
}

void handle_uart_irq() {
    char c;
    while( (reg_read_32( UART_DEVICE, UART_STATUS_REG ) & UART_STATUS_REG__READY) && charsQueue.consume(c) ) {
        uart_send_raw( c );
    }

    if( charsQueue.isEmpty() )
        irq_mask_external( ExtIrq::UART );
}

void uart_send(char c) {
    while( ! charsQueue.produce(c) )
        wfi();

    irq_unmask_external( ExtIrq::UART );
}

void uart_send(const char *str) {
    while( *str )
        uart_send( *(str++) );
}
