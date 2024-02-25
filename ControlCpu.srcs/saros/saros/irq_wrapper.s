.global irq_handler_entry
irq_handler_entry:
    csrw mscratch, sp
    lui         sp, 0x80004

    # Push registers
    addi        sp, sp, -72
    sw          ra, 0x00(sp)
    sw          gp, 0x04(sp)
    sw          tp, 0x08(sp)
    sw          t0, 0x0c(sp)
    sw          t1, 0x10(sp)
    sw          t2, 0x14(sp)
    sw          a0, 0x18(sp)
    sw          a1, 0x1c(sp)
    sw          a2, 0x20(sp)
    sw          a3, 0x24(sp)
    sw          a4, 0x28(sp)
    sw          a5, 0x2c(sp)
    sw          a6, 0x30(sp)
    sw          a7, 0x34(sp)
    sw          t3, 0x38(sp)
    sw          t4, 0x3c(sp)
    sw          t5, 0x40(sp)
    sw          t6, 0x44(sp)

    jal         irq_handler


    # Pop registers
    lw          ra, 0x00(sp)
    lw          gp, 0x04(sp)
    lw          tp, 0x08(sp)
    lw          t0, 0x0c(sp)
    lw          t1, 0x10(sp)
    lw          t2, 0x14(sp)
    lw          a0, 0x18(sp)
    lw          a1, 0x1c(sp)
    lw          a2, 0x20(sp)
    lw          a3, 0x24(sp)
    lw          a4, 0x28(sp)
    lw          a5, 0x2c(sp)
    lw          a6, 0x30(sp)
    lw          a7, 0x34(sp)
    lw          t3, 0x38(sp)
    lw          t4, 0x3c(sp)
    lw          t5, 0x40(sp)
    lw          t6, 0x44(sp)
    addi        sp, sp, 72

    csrr        sp, mscratch
    mret
