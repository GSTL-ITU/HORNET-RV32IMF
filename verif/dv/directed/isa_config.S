# The ISA configuration: misa, and the encodings of M and F instructions as
# words. On a configuration with the extension they execute, without it they
# raise illegal-instruction exceptions (mcause 2 in t6, the handler skips
# them), on the core as on Spike with the same --isa. mstatus.FS is writable
# only with F; the F CSRs exist only with F.
#include "directed.h"
TEST_BEGIN
    csrr a0, misa
    li a2, 6
    li a3, 7
    li t6, 0
    .word 0x02d60533        # mul a0, a2, a3
    mv a4, t6
    .word 0x02d65533        # divu a0, a2, a3
    mv a4, t6
    .word 0x02d61533        # mulh a0, a2, a3
    mv a4, t6
    li t6, 0x6000
    csrs mstatus, t6
    csrr a0, mstatus
    li t6, 0
    .word 0xf00600d3        # fmv.w.x ft1, a2
    mv a4, t6
    .word 0x001080d3        # fadd.s ft1, ft1, ft1
    mv a4, t6
    .word 0xe0008553        # fmv.x.w a0, ft1
    mv a4, t6
    .word 0x00302573        # csrr a0, fcsr
    mv a4, t6
    .word 0x00102573        # csrr a0, fflags
    mv a4, t6
    la t1, tohost
    .word 0x00032087        # flw ft1, 0(t1)
    mv a4, t6
    li t6, 0
    csrw mstatus, zero      # FS = Off: F instructions trap also with F
    .word 0xe0008553
    mv a4, t6
    csrr a0, mstatus
TEST_END
