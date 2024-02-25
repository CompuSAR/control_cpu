#pragma once

#include <stdint.h>

void sleep_ns(uint64_t nanoseconds);
void sleep_cycles(uint64_t cycles);
[[noreturn]] void halt();
void wfi();

void init_irq();

uint32_t get_clock_freq();
uint64_t get_cycles_count();

void set_timer_ns(uint64_t nanoseconds);
void set_timer_cycles(uint64_t cycle_num);
void reset_timer_cycles();

namespace ExtIrq {
enum ExtIrq : uint32_t {
    UART = 0x00000001,
};
}

void irq_mask_external( ExtIrq::ExtIrq irq );
void irq_unmask_external( ExtIrq::ExtIrq irq );

// Interrupt handlers
extern "C"
void irq_handler_entry();

void handle_uart_irq();
