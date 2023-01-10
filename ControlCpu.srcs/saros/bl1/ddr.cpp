#include "ddr.h"

#include "uart.h"
#include "irq.h"
#include "format.h"

static volatile unsigned long *ddr_registers = reinterpret_cast<unsigned long *>(0xc001'0000);

enum class DdrCommands {
    ModeRegisterSet     = 0x0,
    Refresh             = 0x1,
    Precharge           = 0x2,
    BankActivate        = 0x3,
    Write               = 0x4,
    Read                = 0x5,
    NoOperation         = 0xf,
    Calibrate           = 0xe
};

void override_command(DdrCommands cmd) {
}

void ddr_init() {
    ddr_control(0);

    delay_ns(200'000);

    // Take the DDR out of reset
    ddr_control(DDR_RESET_N);

    delay_ns(500'000);

    // Take the DDR PHY out of reset
    ddr_control(DDR_RESET_N|DDR_PHY_RESET_N);

    // Take the DDR controller out of reset, leave in bypass mode with a NOP command loaded
    override_command(DdrCommands::NoOperation);
    ddr_control(DDR_RESET_N|DDR_PHY_RESET_N);
}

uint32_t ddr_status() {
    return ddr_registers[0];
}

void ddr_control(uint32_t status) {
    ddr_registers[0] = status;
}
