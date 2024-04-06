#include "uart.h"

#include "irq.h"
#include "p1c1.h"
#include "reg.h"

#include <cstdint>

static constexpr uint32_t DeviceNum = 0;
static constexpr uint32_t RegUartData = 0x0000;
static constexpr uint32_t RegUartStatus = 0x0004;

static constexpr uint32_t UartStatus__TxReady = 0x00000001;


static volatile unsigned long *uart = reinterpret_cast<unsigned long *>(0xc000'0000);

void uart_send_raw(char c) {
    reg_write_32( DeviceNum, RegUartData, static_cast<unsigned long>(c) & 0xff );
}

static bool uart_tx_ready() {
    return (reg_read_32( DeviceNum, RegUartStatus ) & UartStatus__TxReady) != 0;
}

static P1C1<char> uartBuffer;

void handle_uart_tx_ready_irq() {
    while( uart_tx_ready() && !uartBuffer.isEmpty() )
        uart_send_raw( uartBuffer.consume() );

    if( uartBuffer.isEmpty() ) {
        irq_external_mask( IrqExt__UartTxReady ); 
    }
}

void uart_send(char c) {
    while( uartBuffer.isFull() )
        wfi();

    uartBuffer.produce(c);

    wwb();

    irq_external_unmask( IrqExt__UartTxReady );
}

void uart_send(const char *str) {
    while( *str != '\0' ) {
        uart_send(*str);
        ++str;
    }
}
