#include "spi.h"

#include "reg.h"

namespace SPI {

static constexpr uint32_t SpiDevice = 4;

enum SpiRegister : uint32_t {
    REG_TRIGGER         =       0,
    REG_SEND_DMA_ADDR,
    REG_NUM_SEND_BYTES,
    REG_RECV_DMA_ADDR,
    REG_NUM_RECV_BYTES,
    REG_MODE,
};

void set_config( Config config, uint16_t num_dummy_cycles ) {
    reg_write_32( SpiDevice, REG_MODE, static_cast<uint32_t>(num_dummy_cycles) | (static_cast<uint32_t>(config)<<16) );
}

void start_transaction( const void *read_data, size_t read_size, void *write_data, size_t write_size ) {
    // First write the values that the SPI clocked parts need
    reg_write_32( SpiDevice, REG_NUM_SEND_BYTES, read_size*8 );
    reg_write_32( SpiDevice, REG_NUM_RECV_BYTES, write_size*8 );
    // Then write the values it doesn't, so the first have time to propagate
    reg_write_32( SpiDevice, REG_SEND_DMA_ADDR, reinterpret_cast<uint32_t>(read_data) );
    reg_write_32( SpiDevice, REG_RECV_DMA_ADDR, reinterpret_cast<uint32_t>(write_data) );

    reg_write_32( SpiDevice, REG_TRIGGER, 0 );
}

void wait_transaction() {
    reg_read_32( SpiDevice, REG_TRIGGER );
}

} // namespace SPI
