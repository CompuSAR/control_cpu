#include "spi.h"

static constexpr uint32_t SpiDevice = 4;

enum SpiRegister : uint32_t {
    REG_TRIGGER         =       0,
    REG_SEND_DMA_ADDR,
    REG_NUM_SEND_BYTES,
    REG_RECV_DMA_ADDR,
    REG_NUM_RECV_BYTES,
    REG_MODE,
};
