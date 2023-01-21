#pragma once

#include <stdint.h>

void delay_ns(uint64_t nanoseconds);
void delay_cycles(uint64_t cycles);
void halt();
