# requires: f
# The RISCV-DV paper (ISMSIT 2025, section IV-A): 0x4BB84A00 - 0x3F800001
# (24155136 - 1.0000001) must give 0x4BB849FF in RNE, RTZ, RDN and RMM and
# 0x4BB84A00 only in RUP, with NX. The faulty FPU returned 0x4BB84A00 in the
# modes that round down, and hardwired the dynamic rounding mode: every case
# runs with the static rm field and with frm = 0..4. Also the mirrored and
# scaled forms of the same guard/sticky pattern.
#include "directed.h"
TEST_BEGIN
    FBIN fsub.s, 0x4BB84A00, 0x3F800001
    FBIN fadd.s, 0x4BB84A00, 0xBF800001
    FBIN fsub.s, 0xBF800001, 0x4BB84A00
    FBIN fadd.s, 0xCBB84A00, 0x3F800001
    FBIN fsub.s, 0x4C384A00, 0x40000001
    FBIN fsub.s, 0x4B384A00, 0x3F000001
    FBIN fsub.s, 0x5BB84A00, 0x4F800001
    FBIN fsub.s, 0x0CB84A00, 0x00800001
    # the same through the fused multiply-add: a*1.0 - b
    FTER fmsub.s, 0x4BB84A00, 0x3F800000, 0x3F800001
    FTER fnmadd.s, 0xCBB84A00, 0x3F800000, 0x3F800001
TEST_END
