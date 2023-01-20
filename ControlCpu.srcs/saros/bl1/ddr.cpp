#include "ddr.h"

#include "format.h"
#include "irq.h"
#include "reg.h"
#include "uart.h"

enum class DdrCommands {
    ModeRegisterSet     = 0x0,
    Refresh             = 0x1,
    Precharge           = 0x2,
    BankActivate        = 0x3,
    Write               = 0x4,
    Read                = 0x5,
    Calibrate           = 0x6,
    NoOperation         = 0x7,
};

static constexpr int DdrDevice = 1;

enum DdrRegister {
    DdrControl = 0,
};

static constexpr uint32_t DdrCtrl_ResetAll    = 0x0000;
static constexpr uint32_t DdrCtrl_nMemReset   = 0x0001;
static constexpr uint32_t DdrCtrl_nPhyReset   = 0x0002;
static constexpr uint32_t DdrCtrl_nCtrlReset  = 0x0004;
static constexpr uint32_t DdrCtrl_nBypass     = 0x0008;
static constexpr uint32_t DdrCtrl_Odt         = 0x0010;
static constexpr uint32_t DdrCtrl_Cke         = 0x0020;

static void ddr_control(uint32_t ctrl) {
    reg_write_32(DdrDevice, DdrControl, ctrl);
}

void override_command(DdrCommands cmd) {
}

void ddr_init() {
    // Reset EVERYTHING
    ddr_control(DdrCtrl_ResetAll);

    delay_ns(200'000);

    // Take the DDR out of reset
    ddr_control(DdrCtrl_nMemReset);

    delay_ns(500'000);

    // Take the DDR controller out of reset, leave in bypass mode with a NOP command loaded
    override_command(DdrCommands::NoOperation);
    ddr_control(DdrCtrl_nMemReset|DdrCtrl_nPhyReset);
    ddr_control(DdrCtrl_nMemReset|DdrCtrl_nPhyReset|DdrCtrl_Cke);
}

