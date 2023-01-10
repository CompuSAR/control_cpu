#pragma once

#include <stdint.h>


void ddr_init();

uint32_t ddr_status();

#define DDR_RESET_N             0x0001
#define DDR_PHY_RESET_N         0x0002
#define DDR_CTRL_RESET_N        0x0004
#define DDR_CTRL_BYPASS_N       0x0008
void ddr_control(uint32_t ctrl);
