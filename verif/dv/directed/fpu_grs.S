# requires: f
# Guard, round and sticky bits (paper section IV-A): the addend at the guard,
# round and sticky positions, near cancellation, exact results, tiny operands,
# for FADD, FSUB, FMUL and FMA in all rounding modes (static and dynamic).
#include "directed.h"
TEST_BEGIN
    # 1.0 + 2^-24 (exactly half an ulp: ties), + 3*2^-25, + 2^-25, + 2^-48
    FBIN fadd.s, 0x3F800000, 0x33800000
    FBIN fadd.s, 0x3F800000, 0x34400000
    FBIN fadd.s, 0x3F800000, 0x33000000
    FBIN fadd.s, 0x3F800000, 0x27800000
    FBIN fadd.s, 0x3F800001, 0x33800000
    FBIN fadd.s, 0x3F7FFFFF, 0x33000000
    # 1.0 - 2^-25, 1.0 - 2^-24 - 2^-48 (borrow through the guard bit)
    FBIN fsub.s, 0x3F800000, 0x33000000
    FBIN fsub.s, 0x3F800000, 0x33800001
    FBIN fsub.s, 0x3F800001, 0x3F800000
    FBIN fsub.s, 0x3F800000, 0x3F7FFFFF
    # exact results must not set NX
    FBIN fadd.s, 0x40000000, 0x40400000
    FBIN fsub.s, 0x40400000, 0x40400000
    FBIN fmul.s, 0x3FC00000, 0x40000000
    # products with sticky bits only below the round bit
    FBIN fmul.s, 0x3F800001, 0x3F800001
    FBIN fmul.s, 0x3FFFFFFF, 0x3FFFFFFF
    FBIN fmul.s, 0x3F800001, 0x3F7FFFFF
    FBIN fmul.s, 0x4049ff00, 0x3eaaaaab
    # tiny operands: a normal plus the smallest subnormal
    FBIN fadd.s, 0x3F800000, 0x00000001
    FBIN fsub.s, 0x3F800000, 0x00000001
    FBIN fadd.s, 0x00800000, 0x80000001
    FBIN fsub.s, 0x00000003, 0x00000001
    # fused: the product is exact, the rounding happens once
    FTER fmadd.s, 0x3F800001, 0x3F800001, 0xBF800002
    FTER fmadd.s, 0x3FFFFFFF, 0x3FFFFFFF, 0xC0800000
    FTER fmsub.s, 0x3F800001, 0x3F7FFFFF, 0x3F800000
    FTER fnmsub.s, 0x3F800000, 0x33800000, 0x3F800000
    FTER fmadd.s, 0x00000001, 0x3F000000, 0x00000000
TEST_END
