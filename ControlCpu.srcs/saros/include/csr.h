#pragma once

// Risc V Control Status Register support

namespace CSR {

enum CsrNames : uint32_t {
    mstatus             = 0x300,
    misa,
    medeleg,
    mideleg,
    mie,
    mtvec,
    mcounteren,
    mstatush            = 0x310,

    mscratch            = 0x340,
    mepc,
    mcause,
    mtval,
    mip,
    mtinst              = 0x34a,
    mtval2,

    menvcfg             = 0x30a,
    menvcfgh            = 0x31a,
    mseccfg             = 0x747,
    mxeccfgh            = 0x757,

    mcycle              = 0xb00,
    minstret            = 0xb02,
    mhpmcounter3,
    
    mcycleh             = 0xb80,
    minstreth           = 0xb82,

    mcountinhibit       = 0x320,
    mhpmevent3          = 0x323,
    mhpmevent4,
};

inline uint32_t read_csr(CsrNames csr_num) {
    uint32_t result;
    asm volatile("csrr %0, %1" : "=r"(result) : "I"(csr_num));

    return result;
}

inline void write_csr(CsrNames csr_num, uint32_t value) {
    uint32_t result;
    asm("csrw %0, %1" : : "I"(csr_num), "r"(value));
}

} // namespace CSR
