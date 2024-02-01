#pragma once

static inline void fence() {
    asm volatile("" ::: "memory");
}

static inline void rrb() {
    fence();
}

static inline void rwb() {
    fence();
}

static inline void wrb() {
    fence();
}

static inline void wwb() {
    fence();
}
