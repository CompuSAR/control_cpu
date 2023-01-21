static inline void fence() {
    asm volatile("" ::: "memory");
}
