#include "irq.h"
#include "reg.h"

#define DEVICE_NUM 3

#define REG_HALT 0
#define REG_CPU_CLOCK_FREQ 1
#define REG_CYCLE_COUNT 2
#define REG_WAIT_COUNT 4

void delay_ns(uint64_t nanoseconds) {
    uint64_t cycle_count = reg_read_64(DEVICE_NUM, REG_CYCLE_COUNT);
    reg_write_64(DEVICE_NUM, REG_WAIT_COUNT, cycle_count + nanoseconds*reg_read_32(DEVICE_NUM, REG_CPU_CLOCK_FREQ) / 1'000'000'000);
    reg_read_32(DEVICE_NUM, REG_HALT);
}

void halt() {
    reg_write_64(DEVICE_NUM, REG_WAIT_COUNT, 0xffff'ffff'ffff'ffff);
    reg_read_32(DEVICE_NUM, REG_HALT);
}
