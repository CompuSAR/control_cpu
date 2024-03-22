.global trap_handler_entry
trap_handler_entry:
    csrrw       sp, mscratch, sp

# Push registers
    addi        sp, sp, -0x78
    sw          x1, 0x00(sp)
    sw          x5, 0x08(sp)
    sw          x6, 0x0c(sp)
    sw          x7, 0x10(sp)
    sw          x8, 0x14(sp)
    sw          x9, 0x18(sp)
    csrr        x1, mscratch
    sw          x10, 0x1c(sp)
    sw          x11, 0x20(sp)
    sw          x12, 0x24(sp)
    sw          x13, 0x28(sp)
    sw          x14, 0x2c(sp)
    sw          x15, 0x30(sp)
    sw          x16, 0x34(sp)
    sw          x17, 0x38(sp)
    sw          x1, 0x04(sp)
    sw          x18, 0x3c(sp)
    sw          x19, 0x40(sp)
    sw          x20, 0x44(sp)
    sw          x21, 0x48(sp)
    sw          x22, 0x4c(sp)
    sw          x23, 0x50(sp)
    sw          x24, 0x54(sp)
    sw          x25, 0x58(sp)
    sw          x26, 0x5c(sp)
    sw          x27, 0x60(sp)
    sw          x28, 0x64(sp)
    sw          x29, 0x68(sp)
    sw          x30, 0x6c(sp)
    sw          x31, 0x70(sp)

    jal         trap_handler

    lw          x5, 0x08(sp)
    lw          x6, 0x0c(sp)
    lw          x7, 0x10(sp)
    lw          x8, 0x14(sp)
    lw          x9, 0x18(sp)
    lw          x10, 0x1c(sp)
    lw          x11, 0x20(sp)
    lw          x12, 0x24(sp)
    lw          x13, 0x28(sp)
    lw          x14, 0x2c(sp)
    lw          x15, 0x30(sp)
    lw          x16, 0x34(sp)
    lw          x17, 0x38(sp)
    lw          x1, 0x04(sp)
    lw          x18, 0x3c(sp)
    lw          x19, 0x40(sp)
    lw          x20, 0x44(sp)
    lw          x21, 0x48(sp)
    lw          x22, 0x4c(sp)
    lw          x23, 0x50(sp)
    lw          x24, 0x54(sp)
    csrw        mscratch, x1
    lw          x25, 0x58(sp)
    lw          x26, 0x5c(sp)
    lw          x27, 0x60(sp)
    lw          x28, 0x64(sp)
    lw          x29, 0x68(sp)
    lw          x30, 0x6c(sp)
    lw          x31, 0x70(sp)
    lw          x1, 0x00(sp)

    addi        sp, sp, 0x78

    csrrw       sp, mscratch, sp
    mret
