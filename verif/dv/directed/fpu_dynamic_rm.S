# requires: f
# The dynamic rounding mode comes from frm (the faulty FPU hardwired it): every
# unit with frm = 0..4, the reserved values 5..7 (the instruction is illegal
# with rm = DYN), the reserved static rm fields 5 and 6, fflags accumulation
# and the fcsr/frm/fflags views of the same state.
#include "directed.h"
TEST_BEGIN
    FLI ft1, 0x3F800001
    FLI ft2, 0x40400000
    FLI ft3, 0x3EAAAAAB
    .irp frm, 0, 1, 2, 3, 4, 5, 6, 7
    csrwi frm, \frm
    fadd.s ft0, ft1, ft3
    fmul.s ft0, ft1, ft3
    fdiv.s ft0, ft1, ft2
    fsqrt.s ft0, ft2
    fmadd.s ft0, ft1, ft2, ft3
    fcvt.w.s a0, ft3
    fcvt.s.w ft0, a3
    csrr a1, fcsr
    .endr
    csrwi frm, 0
    # reserved static modes 5 and 6
    .word 0x00308053 | (5 << 12)   # fadd.s ft0, ft1, ft3 with rm = 5
    .word 0x00308053 | (6 << 12)   # rm = 6
    # accumulation: flags are ORed until written
    csrwi fflags, 0
    fdiv.s ft0, ft1, ft2
    fdiv.s ft0, ft1, ft0
    csrr a1, fflags
    csrsi fflags, 0x10
    csrr a1, fcsr
    csrci fflags, 0x1
    csrr a1, fflags
    li a2, 0xFF
    csrw fcsr, a2
    csrr a1, frm
    csrr a1, fflags
    csrr a1, fcsr
TEST_END
