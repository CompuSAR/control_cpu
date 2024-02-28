#include "uart.h"

#include "irq.h"
#include "memory.h"
#include "reg.h"

#include <cstddef>
#include <cstdint>

static constexpr size_t BufferSize = 1024;
static uint8_t buffer[BufferSize];
static volatile size_t buffer_prod = 0, buffer_cons = 0;

static constexpr uint32_t UART_DEVICE = 0;

static constexpr uint32_t UART_DATA_REG =       0x0000;
static constexpr uint32_t UART_STATUS_REG =     0x0004;
static constexpr uint32_t UART_STATUS_REG__READY = 0x00000001;

void uart_send_raw(char c) {
    reg_write_32( UART_DEVICE, UART_DATA_REG, c );
}

void handle_uart_irq() {
    while( buffer_prod!=buffer_cons && (reg_read_32( UART_DEVICE, UART_STATUS_REG ) & UART_STATUS_REG__READY) ) {
        uart_send_raw( buffer[buffer_cons] );
        rwb();
        buffer_cons = (buffer_cons+1) % BufferSize;
    }

    if( buffer_prod==buffer_cons )
        irq_mask_external( ExtIrq::UART );
}

void uart_send(char c) {
    while( (buffer_prod+1)%BufferSize == buffer_cons )
        wfi();

    buffer[buffer_prod] = c;
    wwb();
    buffer_prod = (buffer_prod + 1) % BufferSize;

    irq_unmask_external( ExtIrq::UART );
}

void uart_send(const char *str) {
    while( *str )
        uart_send( *(str++) );
}
