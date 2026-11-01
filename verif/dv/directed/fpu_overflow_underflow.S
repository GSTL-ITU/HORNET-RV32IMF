# requires: f
# Rounding at overflow and underflow (paper section IV-A): results around the
# largest finite value (OF, NX, rounding to infinity or to the largest
# finite number depending on the mode) and around the subnormal range (UF
# with tininess after rounding, as RISC-V and Spike define it).
#include "directed.h"
TEST_BEGIN
    FBIN fadd.s, 0x7F7FFFFF, 0x73800000
    FBIN fadd.s, 0x7F7FFFFF, 0x73000000
    FBIN fadd.s, 0x7F7FFFFF, 0x7F7FFFFF
    FBIN fsub.s, 0xFF7FFFFF, 0x73800000
    FBIN fmul.s, 0x7F7FFFFF, 0x3F800001
    FBIN fmul.s, 0x7F000000, 0x40000000
    FBIN fmul.s, 0xFF000000, 0x40000000
    FBIN fdiv.s, 0x7F7FFFFF, 0x3F7FFFFF
    FBIN fdiv.s, 0x7F000000, 0x00800000
    # underflow: products and quotients that land below 2^-126
    FBIN fmul.s, 0x00800000, 0x3F7FFFFF
    FBIN fmul.s, 0x00800001, 0x3F000000
    FBIN fmul.s, 0x00FFFFFF, 0x3F000000
    FBIN fmul.s, 0x1E000000, 0x21000000
    FBIN fmul.s, 0x00000001, 0x3F000000
    FBIN fmul.s, 0x00000001, 0x3F400000
    FBIN fdiv.s, 0x00800000, 0x40000000
    FBIN fdiv.s, 0x00000001, 0x40000000
    FBIN fadd.s, 0x00800000, 0x80000001
    FTER fmadd.s, 0x00800000, 0x3F7FFFFF, 0x80000000
    FTER fmadd.s, 0x7F7FFFFF, 0x40000000, 0xFF7FFFFF
    FTER fnmadd.s, 0x7F7FFFFF, 0x7F7FFFFF, 0x3F800000
TEST_END
