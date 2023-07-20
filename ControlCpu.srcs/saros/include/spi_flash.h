#pragma once

#include <cstdint>
#include <cstddef>

namespace SPI_FLASH {

void init_flash();
void initiate_read(uint32_t start_address, size_t size, void *dest);

} // namespace SPI_FLASH
