# requires: f
# Integer conversions near the ends of the range and at infinity (paper
# section IV-A): FCVT.W.S and FCVT.WU.S saturate and set NV out of range,
# round in every mode inside it; FCVT.S.W and FCVT.S.WU round large integers.
#include "directed.h"
TEST_BEGIN
    .irp a, 0x00000000, 0x80000000, 0x3F000000, 0xBF000000, 0x3FC00000, 0xBFC00000, 0x40200000, 0xC0200000, 0x3F7FFFFF, 0x4EFFFFFF, 0x4F000000, 0xCF000000, 0xCF000001, 0x4F7FFFFF, 0x4F800000, 0x7F800000, 0xFF800000, 0x7FC00000, 0x7FA00000, 0x00000001, 0xB3800000
    FTOI fcvt.w.s, \a
    FTOI fcvt.wu.s, \a
    .endr
    .irp v, 0, 1, -1, 16777217, -16777217, 0x7FFFFFFF, 0x80000000, 0x7FFFFFC0, 0xFFFFFF7F, 0x01000003
    ITOF fcvt.s.w, \v
    ITOF fcvt.s.wu, \v
    .endr
TEST_END
