# requires: f
# Division and square root of subnormals (paper section IV-B): the faulty
# divider did not normalise a subnormal dividend, the square root lost
# precision on subnormal inputs. Subnormal dividends, divisors and square
# root inputs at many exponent positions, plus boundary mantissas.
#include "directed.h"
TEST_BEGIN
    .irp a, 0x00000001, 0x00000003, 0x00000155, 0x00001000, 0x0002AAAB, 0x00400000, 0x007FFFFF, 0x80000007
    FBIN fdiv.s, \a, 0x3F800000
    FBIN fdiv.s, \a, 0x3FC00000
    FBIN fdiv.s, \a, 0x00000003
    FBIN fdiv.s, 0x3F800000, \a
    FBIN fdiv.s, \a, 0x7F000000
    FUN fsqrt.s, \a
    .endr
    .irp a, 0x00000002, 0x00000008, 0x00000020, 0x00000080, 0x00000200, 0x00000800, 0x00002000, 0x00008000, 0x00020000, 0x00080000, 0x00200000, 0x00600000
    FUN fsqrt.s, \a
    .endr
    # normal boundaries and special values
    .irp a, 0x00800000, 0x3F800000, 0x3F800001, 0x3FFFFFFF, 0x40000000, 0x7F7FFFFF, 0x7F800000, 0xBF800000, 0x7FC00000, 0x80000000
    FUN fsqrt.s, \a
    .endr
    FBIN fdiv.s, 0x3F800000, 0x40400000
    FBIN fdiv.s, 0x3F800000, 0x00000000
    FBIN fdiv.s, 0x00000000, 0x00000000
    FBIN fdiv.s, 0x7F800000, 0x7F800000
TEST_END
