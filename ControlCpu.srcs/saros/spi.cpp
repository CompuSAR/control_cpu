#include "spi.h"

#include "reg.h"

namespace SPI {

static constexpr uint32_t SpiDevice = 4;

enum SpiRegister : uint32_t {
    REG_TRIGGER         =       0,
    REG_SEND_DMA_ADDR,
    REG_NUM_SEND_CYCLES,
    REG_RECV_DMA_ADDR,
    REG_NUM_RECV_CYCLES,
    REG_MODE,
};

void set_config( Config config, uint16_t num_dummy_cycles ) {
    reg_write_32( SpiDevice, REG_MODE, static_cast<uint32_t>(num_dummy_cycles) | (static_cast<uint32_t>(config)<<16) );
}

void start_transaction( const void *read_data, size_t read_size, void *write_data, size_t write_size ) {
    // First write the values that the SPI clocked parts need
    Config current_config = Config( reg_read_32(SpiDevice, REG_MODE) );
    if( current_config==Config::ESPI ) {
        reg_write_32( SpiDevice, REG_NUM_SEND_CYCLES, read_size*8 );
        reg_write_32( SpiDevice, REG_NUM_RECV_CYCLES, write_size*8 );
    } else {
        reg_write_32( SpiDevice, REG_NUM_SEND_CYCLES, read_size*2 );
        reg_write_32( SpiDevice, REG_NUM_RECV_CYCLES, write_size*2 );
    }
    // Then write the values it doesn't, so the first have time to propagate
    reg_write_32( SpiDevice, REG_SEND_DMA_ADDR, reinterpret_cast<uint32_t>(read_data) );
    reg_write_32( SpiDevice, REG_RECV_DMA_ADDR, reinterpret_cast<uint32_t>(write_data) );

    reg_write_32( SpiDevice, REG_TRIGGER, 0 );
}

void wait_transaction() {
    reg_read_32( SpiDevice, REG_TRIGGER );
}

struct RecoveryData {
    uint8_t data[5] = {
        0xff, 0xff, 0xff, 0xff, 0x01
    };
} __attribute__((aligned(16) ))__;
const RecoveryData RecoveryFirstStepData;
static void recovery_helper(uint32_t num_cycles) {
    set_config( Config::ESPI, 0 );
    reg_write_32( SpiDevice, REG_NUM_SEND_CYCLES, num_cycles );
    reg_write_32( SpiDevice, REG_NUM_RECV_CYCLES, 0 );
    reg_write_32( SpiDevice, REG_SEND_DMA_ADDR, reinterpret_cast<uint32_t>(&RecoveryFirstStepData.data) );
    reg_write_32( SpiDevice, REG_RECV_DMA_ADDR, 0 );
    reg_write_32( SpiDevice, REG_TRIGGER, 0 );
}

static void recovery_first_step() {
    recovery_helper(7);
    recovery_helper(9);
    recovery_helper(13);
    recovery_helper(17);
    recovery_helper(25);
    recovery_helper(33);
}

void interface_rescue() {
    recovery_first_step();
    recovery_helper(16);
}

} // namespace SPI
