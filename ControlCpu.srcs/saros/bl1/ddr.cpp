#include "ddr.h"

#include "uart.h"
#include "format.h"

static volatile unsigned long *ddr_registers = reinterpret_cast<unsigned long *>(0xc001'0000);

void ddr_init() {
    uint32_t last_status = ddr_status();
    uart_send("Starting test with status ");
    print_hex(last_status);

    for( uint32_t i=0; i<4; ++i ) {
        uart_send("\nSetting control to ");
        print_hex(i);
        ddr_control(i);

        for( uint32_t j=0; j<1000; ++j ) {
            uint32_t status = ddr_status();

            if( status!=last_status ) {
                uart_send("\nStatus changed to ");
                print_hex(status);
                uart_send(" after iteration: ");
                print_hex(j);
                last_status = status;
            }
        }
    }
    uart_send("\nAll tests done\n");
}

uint32_t ddr_status() {
    return ddr_registers[0];
}

void ddr_control(uint32_t status) {
    ddr_registers[0] = status;
}
