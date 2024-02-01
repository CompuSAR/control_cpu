#pragma once

#include <stdint.h>

enum class CSR {
    mvendorid = 0xf11,
    marchid = 0xf12,
    mimpid = 0xf13,
    mhartid = 0xf14,

    mstatus = 0x0300,
    misa = 0x301,
    mie = 0x304,
    mtvec = 0x305,
    mscratch = 0x340,
    mepc = 0x341,
    mcause = 0x342,
    mtval = 0x343,
    mip = 0x344,

    mcycle = 0xb00,
    mcycleh = 0xb80,
    minstret = 0xb02,
    minstreth = 0xb82,

    sstatus = 0x100,

    ustatus = 0x000,
    uie = 0x004,
    utvec = 0x005,
    uscratch = 0x040,

    cycle = 0xc00,
    cycleh = 0xc80,
    time = 0xc01,
    timeh = 0xc81,
    instret = 0xc02,
    instreth = 0xc82,
};

static inline uint32_t csr_read(CSR csr) {
    uint32_t result;

    asm volatile ("csrr %0, %1": "=r" (result): "i"(csr));

    return result;
}

static inline void csr_write(CSR csr, uint32_t value) {
    asm volatile ("csrw %1, %0": : "r" (value), "i"(csr));
}

static inline uint32_t csr_read_write(CSR csr, uint32_t value) {
    uint32_t result;

    asm volatile ("csrrw %0, %1, %2": "=r"(result): "i"(csr), "r" (value));

    return result;
}
