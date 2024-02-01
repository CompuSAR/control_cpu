#pragma once

#include <stdint.h>

void sleep_ns(uint64_t nanoseconds);
void sleep_cycles(uint64_t cycles);
[[noreturn]] void halt();

uint32_t get_clock_freq();
uint64_t get_cycles_count();

void set_timer_ns(uint64_t nanoseconds);
void set_timer_cycles(uint64_t cycle_num);
void reset_timer_cycles();
