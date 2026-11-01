# Forwarding and stalls: load-use, a load into a branch and into JALR, a CSR
# read used at once, back-to-back writes to the same register, stores of just
# computed data, FENCE.I after a store into the program (self-modifying code).
#include "directed.h"
TEST_BEGIN
    la s0, data
    lw a0, 0(s0)
    addi a1, a0, 1
    lw a2, 4(s0)
    beq a2, a0, 1f
    add a3, a2, a2
1:  lw a4, 8(s0)
    la a5, 2f
    sw a5, 12(s0)
    lw a5, 12(s0)
    jalr ra, 0(a5)
2:  csrr a6, mscratch
    addi a6, a6, 3
    csrw mscratch, a6
    csrr a7, mscratch
    add a7, a7, a7
    li t0, 1
    li t0, 2
    add t1, t0, t0
    sw t1, 16(s0)
    lw t2, 16(s0)
    sb t2, 21(s0)
    lh t3, 20(s0)
    lbu t4, 21(s0)
    # misaligned: trap with cause 4/6
    lw t5, 1(s0)
    sh t5, 3(s0)
    mv a0, t6
    # FENCE.I: patch the next instruction (li a0, 1 -> li a0, 2)
    la a1, 3f
    li a2, 0x00200513
    sw a2, 0(a1)
    fence.i
3:  li a0, 1
    .rept 8
    lw a3, 0(s0)
    add a3, a3, a3
    sw a3, 0(s0)
    .endr
TEST_END
    .align 4
data:
    .word 0x11111111, 0x11111111, 0x33333333, 0, 0, 0, 0, 0
