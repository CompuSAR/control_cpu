.global _start
_start:
        lui     ra, 0                   # Set return address to NULL
        lui     sp, (32*1024)>>12       # Set stack pointer to end of memory (32KB)
        lui     gp, 0
        lui     tp, 0
        jal     zero, bl1_start
