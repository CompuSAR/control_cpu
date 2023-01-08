#pragma once

#include <stdint.h>


void ddr_init();

#define DDR_STAT_MMCM_LOCKED            0x01
#define DDR_STAT_CALIB_COMPLETE         0x02
#define DDR_STAT_CLK_SYNC_RST           0x04
uint32_t ddr_status();

#define DDR_RESET_N 1
#define DDR_PHY_RESET_N 2
#define DDR_CTRL_RESET_N 4
void ddr_control(uint32_t ctrl);
