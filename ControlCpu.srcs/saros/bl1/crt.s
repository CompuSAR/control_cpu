.global _start
_start:
        lui     ra, 0                   # Set return address to NULL
        lui     sp, 0x80008             # Set stack pointer to end of static memory (32KB + base)
        lui     gp, 0
        lui     tp, 0
        jal     zero, bl1_start
