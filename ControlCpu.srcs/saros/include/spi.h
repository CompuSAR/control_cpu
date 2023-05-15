#pragma once

#include <stdint.h>
#include <stddef.h>

namespace SPI {

enum class Config {
    ESPI = 0,
    QSPI,
};

void set_config( Config config, uint16_t num_dummy_cycles );
void start_transaction( const void *read_data, size_t read_size, void *write_data, size_t write_size );
void wait_transaction();

} // namespace SPI
