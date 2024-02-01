.global _start
_start:
        lui     ra, 0                   # Set return address to NULL
        lui     sp, 0x80004             # Set stack pointer to end of pre-cached memory (16KB + base)
        lui     gp, 0
        lui     tp, 0
        j       bl1_start
