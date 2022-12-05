#include "ddr.h"

static volatile unsigned long *ddr_registers = reinterpret_cast<unsigned long *>(0xc001'0000);

void ddr_init() {
    ddr_control(0);
    volatile int i;
    for(i=0; i<100; ++i)
        ;

    ddr_control(DDR_CTRL_RESET_N|DDR_CTRL_RESET_P);
    while( ! (ddr_status() & DDR_STAT_MMCM_LOCKED) )
        ;
    while( ! (ddr_status() & DDR_STAT_CALIB_COMPLETE) )
        ;
}

uint32_t ddr_status() {
    return ddr_registers[0];
}

void ddr_control(uint32_t status) {
    ddr_registers[0] = status;
}
