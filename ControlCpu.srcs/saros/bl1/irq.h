#pragma once

#include <stdint.h>

void sleep_ns(uint64_t nanoseconds);
void sleep_cycles(uint64_t cycles);
void halt();
