# requires: m
# M extension corner cases: division by zero, signed overflow, the high halves
# of the products for every sign combination, and back-to-back dependent
# multiply/divide (the multiplier result is late, the divider stalls EX).
#include "directed.h"
TEST_BEGIN
    .irp a, 0, 1, -1, 7, -7, 0x7FFFFFFF, 0x80000000, 0x12345678, 0xFFFF0000
    .irp b, 0, 1, -1, 3, -3, 0x7FFFFFFF, 0x80000000, 0x10000
    li a2, \a
    li a3, \b
    mul a0, a2, a3
    mulh a0, a2, a3
    mulhsu a0, a2, a3
    mulhu a0, a2, a3
    div a0, a2, a3
    divu a0, a2, a3
    rem a0, a2, a3
    remu a0, a2, a3
    .endr
    .endr
    # dependent chains
    li a2, 12345
    li a3, 678
    mul a0, a2, a3
    div a4, a0, a3
    mul a5, a4, a4
    rem a0, a5, a2
    add a0, a0, a5
    divu a4, a0, a0
    mulhu a5, a4, a0
TEST_END
