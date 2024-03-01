#include "irq.h"

#include "format.h"

#include "csr.h"
#include "memory.h"
#include "reg.h"

#define DEVICE_NUM 3

#define REG_HALT                        0x0000
#define REG_CPU_CLOCK_FREQ              0x0004
#define REG_CYCLE_COUNT                 0x0008
#define REG_WAIT_COUNT                  0x0010
#define REG_INT_CYCLE                   0x0200
#define REG_RESET_INT_CYCLE             0x0210

#define REG_ACTIVE_UNMASKED_IRQS        0x0400
#define REG_ACTIVE_IRQS                 0x0404
#define REG_IRQ_MASK_SET                0x0500
#define REG_IRQ_MASK_CLEAR              0x0580

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

void halt() {
    while( true ) {
        wfi();
    }
}

void wfi() {
    reg_write_64(DEVICE_NUM, REG_WAIT_COUNT, 0xffff'ffff'ffff'ffff);
    reg_read_32(DEVICE_NUM, REG_HALT);
}

#ifdef SAROS

void irq_mask_external( ExtIrq::ExtIrq irq ) {
    reg_write_32( DEVICE_NUM, REG_IRQ_MASK_SET, irq );
}

void irq_unmask_external( ExtIrq::ExtIrq irq ) {
    reg_write_32( DEVICE_NUM, REG_IRQ_MASK_CLEAR, irq );
}

uint32_t irq_external_get_mask() {
    return reg_read_32( DEVICE_NUM, REG_IRQ_MASK_CLEAR );
}

static void handle_software_interrupt() {
    // TODO implement
}

static void handle_timer_interrupt() {
    // TODO implement
}

static void handle_external_interrupt() {
    uint32_t pending = reg_read_32( DEVICE_NUM, REG_ACTIVE_UNMASKED_IRQS );

    if( pending & ExtIrq::UART )
        handle_uart_irq();
}

extern "C"
void irq_handler() {
    uint32_t cause = csr_read(CSR::mcause);

    if( cause & 0x80000000 ) {
        // Interrupt

        switch( cause & 0x7fffffff ) {
        case 3:
            handle_software_interrupt();
            break;
        case 7:
            handle_timer_interrupt();
            break;
        case 11:
            handle_external_interrupt();
            break;
        default:
            // Unknown interrupt cause
            break;
        }

    } else {
        // Exception
        // TODO implement
    }
}

void init_irq() {
    // Set trap handler
    auto handler = reinterpret_cast<uintptr_t>(irq_handler_entry);
    csr_write(CSR::mtvec, handler );

    irq_mask_external( ExtIrq::ALL );

    // Enable External and Timer interrupts
    csr_write(CSR::mie, MIE__MEIE | MIE__MTIE );

    // Master interrupt enable
    csr_read_set_bits(CSR::mstatus, MSTATUS__MIE);
}

#endif
