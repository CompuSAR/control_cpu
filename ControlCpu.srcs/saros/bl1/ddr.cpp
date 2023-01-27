#include "ddr.h"

#include "format.h"
#include "irq.h"
#include "memory.h"
#include "reg.h"
#include "uart.h"

static constexpr uint32_t BankBits = 3;
static constexpr uint32_t AddrBits = 14;

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
    DdrOverrideCommand,
    DdrAddress,
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
    fence();
    reg_write_32(DdrDevice, DdrOverrideCommand, static_cast<uint32_t>(cmd));
}

constexpr uint32_t composeDdrAddress(uint32_t bank, uint32_t address) {
    return bank<<(32-BankBits) | address&((1<<AddrBits) - 1);
}

void write_mode_reg0(uint32_t bl, uint32_t cl, uint32_t bt, bool dllReset, uint32_t writeRecovery, bool prechardPd) {
    uint32_t value = 0; // Register 0

    // Burst length
    value |= bl;

    // CAS latency
    value |= (cl&1) << 2;
    value |= (cl&0xe) << (4-1);

    // Read burst type
    value |= bt << 3;

    // DLL reset
    value |= dllReset ? 1<<8 : 0;

    // Write recovery
    value |= writeRecovery << 9;

    // Prechard PD
    value |= prechardPd << 12;

    reg_write_32(DdrDevice, DdrAddress, composeDdrAddress(0, value));
    override_command(DdrCommands::ModeRegisterSet);
}

void write_mode_reg1(bool dllDisable, uint32_t ods, uint32_t rtt, uint32_t al, bool wl, bool tqds, bool outputEnable) {
    uint32_t value = 0; // Register 1

    // DLL enable
    value |= dllDisable ? 1 : 0;

    // Output drive strength
    value |= (ods&1) << 1;
    value |= (ods&2) << (5-1);

    // ODT resistance
    value |= (rtt&1) << 2;
    value |= (rtt&2) << (6-1);
    value |= (rtt&4) << (9-2);

    // Added latency
    value |= al << 3;

    // Write leveling
    value |= wl ? 1<<7 : 0;

    // TQDS termination
    value |= tqds ? 1<<11 : 0;

    // Output enable
    value |= outputEnable ? 0 : 1<<12;

    reg_write_32( DdrDevice, DdrAddress, composeDdrAddress(1, value) );
    override_command(DdrCommands::ModeRegisterSet);
}

void write_mode_reg2(uint32_t casWriteLatency, bool autoSelfRefresh, uint32_t selfRefreshTemperature, uint32_t rtt) {
    uint32_t value = 0; // Register 2

    // CAS write latency
    value |= casWriteLatency<<3;

    // Auto self refresh
    value |= autoSelfRefresh ? 1<<6 : 0;

    // Self refresh temperature
    value |= selfRefreshTemperature << 7;

    // Dynamic ODT RTT(WR)
    value |= rtt << 9;

    reg_write_32( DdrDevice, DdrAddress, composeDdrAddress(2, value) );
    override_command(DdrCommands::ModeRegisterSet);
}

void write_mode_reg3(uint32_t mpr_rf, bool mprEnable) {
    uint32_t value = 0; // Register 3

    // MPR read function
    value |= mpr_rf;

    // MPR enable
    value |= mprEnable ? 1<<2 : 0;

    reg_write_32( DdrDevice, DdrAddress, composeDdrAddress(3, value) );
    override_command(DdrCommands::ModeRegisterSet);
}

void ddr_init() {
    // Reset EVERYTHING
    ddr_control(DdrCtrl_ResetAll);
    override_command(DdrCommands::NoOperation);         // Set CKE low

    sleep_ns(200'000);

    // Take the DDR out of reset
    ddr_control(DdrCtrl_nMemReset);

    sleep_ns(500'000);

    // Take the DDR PHY out of reset
    ddr_control(DdrCtrl_nMemReset|DdrCtrl_nPhyReset);
    // Set clock enable.
    ddr_control(DdrCtrl_nMemReset|DdrCtrl_nPhyReset|DdrCtrl_Cke); // CKE will take effect at next override command
    override_command(DdrCommands::NoOperation);

    sleep_ns(360);      // tXPR = tRFC (350ns) + 10ns

    write_mode_reg2(
            1,          // CAS write latency 6 due to DLL disabled
                        // 0 (5) if DLL is on
            false,      // Manual refersh
            0,          // Normal selft refresh temperature
            0           // RTT disabled
        );
    sleep_cycles(4);    // tMRD

    write_mode_reg3(
            0,          // Predefined MPR pattern
            false       // Multi Purpose Register read disabled
        );
    sleep_cycles(4);    // tMRD

    // Finish initialization with DLL enabled. We're violating the specs as our clock is too slow, but I'm hoping
    // that'll be okay, as we're not issuing any memory accesses and don't care about memory content yet.
    write_mode_reg1(
            false,      // DLL enabled during init (default)
            1,          // Out drive stength 34Ohm (default)
            1,          // RTT 60ohm (default)
            0,          // Additive latency disabled (we have enough latency already)
            false,      // Write leveling disabled
            false,      // TDQS disabled (and irrelevant for our x16 chip)
            true        // Output enabled
        );
    sleep_cycles(4);    // tMRD

    write_mode_reg0(
            0,          // Burst length fixed BL8
            4,          // CAS latency 6 (due to DLL off, default 5)
            0,          // Burst type sequential
            true,       // Reset the DLL for the init process (default)
            1,          // Write recovery 5 (tWR=15ns, tCK=10ns at 100MHz. tWR/tCK=1.5. 5 is minimal allowed value.
            0           // Precharge PD DLL off
        );

    sleep_cycles(12);   // tMOD

    reg_write_32( DdrDevice, DdrAddress, 1<<10 ); // Select long calibration
    override_command(DdrCommands::Calibrate);

    sleep_cycles(512);  // tZQinit

    // Initialization complete. Initiate switch to DLL off mode

    write_mode_reg1(
            true,       // DLL disabled
            1,          // Out drive stength 34Ohm (default)
            1,          // RTT 60ohm (default)
            0,          // Additive latency disabled (we have enough latency already)
            false,      // Write leveling disabled
            false,      // TDQS disabled (and irrelevant for our x16 chip)
            true        // Output enabled
        );
    sleep_cycles(4);    // tMRD
    write_mode_reg0(
            0,          // Burst length fixed BL8
            4,          // CAS latency 6 (due to DLL off, default 5)
            0,          // Burst type sequential
            false,      // Don't reset the DLL, as we're not using it (default TRUE)
            1,          // Write recovery 5 (tWR=15ns, tCK=10ns at 100MHz. tWR/tCK=1.5. 5 is minimal allowed value.
            0           // Precharge PD DLL off
        );

    sleep_cycles(12);   // tMOD

    // Enter self refresh mode
    ddr_control(DdrCtrl_nMemReset|DdrCtrl_nPhyReset); // CKE low will take effect at next override command
    override_command(DdrCommands::Refresh);
    sleep_cycles(10);   // tCKSRE + tCKSRX. tCKESR is just 4, and is probably the correct one, but we're playing it safe.

    ddr_control(DdrCtrl_nMemReset|DdrCtrl_nPhyReset|DdrCtrl_Cke); // CKE high will take effect at next override command
    override_command(DdrCommands::NoOperation);
    sleep_ns(360);      // tXS = tRFC + 10ns

    reg_write_32( DdrDevice, DdrAddress, 1<<10 ); // Select long calibration
    override_command(DdrCommands::Calibrate);
    sleep_cycles(256);  // tZQoper

    ddr_control(DdrCtrl_nMemReset|DdrCtrl_nPhyReset|DdrCtrl_Cke|DdrCtrl_nBypass);
}

