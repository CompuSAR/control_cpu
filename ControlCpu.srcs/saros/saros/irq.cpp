#include "csr.h"
#include "irq.h"
#include "memory.h"
#include "reg.h"
#include "uart.h"

#define DEVICE_NUM 3

#define REG_HALT                0x0000
#define REG_CPU_CLOCK_FREQ      0x0004
#define REG_CYCLE_COUNT         0x0008
#define REG_WAIT_COUNT          0x0010
#define REG_INT_CYCLE           0x0200
#define REG_RESET_INT_CYCLE     0x0210

#define REG_ACTIVE_IRQS         0x0400
#define REG_IRQ_MASK_SET        0x0500
#define REG_IRQ_MASK_CLEAR      0x0580

void sleep_ns(uint64_t nanoseconds) {
    sleep_cycles(nanoseconds*reg_read_32(DEVICE_NUM, REG_CPU_CLOCK_FREQ) / 1'000'000'000);
}

void sleep_cycles(uint64_t cycles) {
    uint64_t cycle_count = reg_read_64(DEVICE_NUM, REG_CYCLE_COUNT);
    reg_write_64(DEVICE_NUM, REG_WAIT_COUNT, cycle_count + cycles);
    reg_read_32(DEVICE_NUM, REG_HALT);
}

void set_timer_ns(uint64_t nanoseconds) {
    set_timer_cycles(get_cycles_count() + nanoseconds*get_clock_freq() / 1'000'000'000);
}

void set_timer_cycles(uint64_t cycles_num) {
    reg_write_32(DEVICE_NUM, REG_INT_CYCLE+1, cycles_num>>32);
    wwb();
    reg_write_32(DEVICE_NUM, REG_INT_CYCLE, cycles_num & 0xffffffff);
}

void reset_timer_cycles() {
    reg_write_32(DEVICE_NUM, REG_RESET_INT_CYCLE, 0);
}

uint32_t get_clock_freq() {
    return reg_read_32(DEVICE_NUM, REG_CPU_CLOCK_FREQ);
}

uint64_t get_cycles_count() {
    uint64_t cycles_count = reg_read_32(DEVICE_NUM, REG_CYCLE_COUNT);
    rrb();
    cycles_count |= static_cast<uint64_t>( reg_read_32(DEVICE_NUM, REG_CYCLE_COUNT+1) )<<32;

    return cycles_count;
}

void wfi() {
    reg_write_64(DEVICE_NUM, REG_WAIT_COUNT, 0xffff'ffff'ffff'ffff);
    reg_read_32(DEVICE_NUM, REG_HALT);
}

void halt() {
    while( true ) {
        wfi();
    }
}

extern "C"
void trap_handler_entry();

static void handle_software_interrupt() {
    // TODO implement
}

static void handle_timer_interrupt() {
    // TODO implement
}

static void handle_external_interrupt() {
    uint32_t active_irqs = reg_read_32( DEVICE_NUM, REG_ACTIVE_IRQS );

    if( (active_irqs & IrqExt__UartTxReady) != 0 )
        handle_uart_tx_ready_irq();
}

extern "C"
void trap_handler() {
    uint32_t cause = csr_read(CSR::mcause);
    if( cause & 0x80000000 ) {
        // Interrupt
        switch( cause & 0x7fffffff ) {
        case MIE__MSIE_BIT: handle_software_interrupt(); break;
        case MIE__MTIE_BIT: handle_timer_interrupt(); break;
        case MIE__MEIE_BIT: handle_external_interrupt(); break;
        default: // TODO handle invalid case
                            ;
        }
    } else {
        // Trap
        // TODO implement
    }
}

void irq_external_mask( uint32_t mask ) {
    reg_write_32( DEVICE_NUM, REG_IRQ_MASK_SET, mask );
}

void irq_external_unmask( uint32_t mask ) {
    reg_write_32( DEVICE_NUM, REG_IRQ_MASK_CLEAR, mask );
}

void irq_init() {
    auto trap = reinterpret_cast<uintptr_t>(trap_handler_entry);
    csr_write(CSR::mtvec, trap );

    // IRQ stack pointer
    csr_write(CSR::mscratch, 0x80008000);

    irq_external_mask(0xffffffff);

    csr_read_set_bits( CSR::mie, MIE__MEIE_MASK );
    csr_read_set_bits( CSR::mstatus, MSTATUS__MIE );
}
