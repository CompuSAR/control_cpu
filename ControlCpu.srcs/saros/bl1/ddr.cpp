#include "ddr.h"

#include "uart.h"
#include "format.h"

static volatile unsigned long *ddr_registers = reinterpret_cast<unsigned long *>(0xc001'0000);

void ddr_init() {
    ddr_control(DDR_CTRL_RESET_N);
    ddr_control(DDR_CTRL_RESET_P);
    uint32_t j;
    for( j=0; j<1000 && (ddr_status() & DDR_STAT_CLK_SYNC_RST)==0; ++j ) {
    }

    uint32_t status = ddr_status();
    static constexpr uint32_t mask = DDR_STAT_CALIB_COMPLETE;
    for( j=0; j<1000 && (status & mask)!=mask; ++j ) {
        status = ddr_status();
    }

    if( j==1000 )
        uart_send("D-\n");
    else
        uart_send("D+\n");
}

uint32_t ddr_status() {
    return ddr_registers[0];
}

void ddr_control(uint32_t status) {
    ddr_registers[0] = status;
}
