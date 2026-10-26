// FPU from C: results are compared bit-exactly, flags are checked after each group
#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include "hornet.h"

typedef union { float f; uint32_t u; } fu;

static int errors;
static void expect(const char *name, float got, uint32_t want)
{
    fu v = { .f = got };
    if (v.u != want) {
        printf("%s: %08lx expected %08lx\n", name, (unsigned long)v.u, (unsigned long)want);
        errors++;
    }
}

volatile float a = 3.0f, b = 7.0f, c = -1.25f, tiny = 1e-38f, big = 3e38f, neg = -4.0f;

int main(void)
{
    write_csr(fflags, 0);
    expect("div", a / b, 0x3edb6db7);
    expect("sqrt", sqrtf(b), 0x402953fd);
    expect("fma", fmaf(a, b, c), 0x419e0000);
    expect("fms", a * b - c, 0x41b20000);
    uint32_t f1 = read_csr(fflags);
    if (f1 != 0x01) { printf("fflags %lx expected 1 (NX)\n", (unsigned long)f1); errors++; }

    write_csr(fflags, 0);
    expect("overflow", big * b, 0x7f800000);
    expect("underflow", tiny * tiny, 0x00000000);
    expect("sqrt(-4)", sqrtf(neg), 0x7fc00000);
    expect("1/0", a / (b - b), 0x7f800000);
    uint32_t f2 = read_csr(fflags);
    if (f2 != 0x1f) { printf("fflags %lx expected 1f\n", (unsigned long)f2); errors++; }

    int i = (int)(b / a);
    unsigned u = (unsigned)(-c);
    float back = (float)123456789;
    if (i != 2 || u != 1) errors++;
    expect("i2f", back, 0x4ceb79a3);
    expect("min", fminf(a, c), 0xbfa00000);
    expect("max", fmaxf(a, NAN), 0x40400000);

    __asm__ volatile ("csrwi frm, 3" ::: "memory");   // round up
    expect("rup", b / a, 0x40155556);
    __asm__ volatile ("csrwi frm, 0" ::: "memory");
    expect("rne", b / a, 0x40155555);

    // 0x4BB84A00 - 0x3F800001 (24155136 - 1.0000001), a version 1 rounding bug:
    // 0x4BB849FF in every mode except RUP; dynamic (frm) and static rm field
    static const uint32_t want_sub[5] = { 0x4bb849ff, 0x4bb849ff, 0x4bb849ff, 0x4bb84a00, 0x4bb849ff };
    volatile fu big_ = { .u = 0x4bb84a00 }, one_ = { .u = 0x3f800001 };
    for (uint32_t rm = 0; rm < 5; rm++) {
        write_csr(frm, rm);
        expect("sub dyn", big_.f - one_.f, want_sub[rm]);
    }
    write_csr(frm, 0);
    float r;
    __asm__ volatile ("fsub.s %0, %1, %2, rne" : "=f"(r) : "f"(big_.f), "f"(one_.f));
    expect("sub rne", r, want_sub[0]);
    __asm__ volatile ("fsub.s %0, %1, %2, rtz" : "=f"(r) : "f"(big_.f), "f"(one_.f));
    expect("sub rtz", r, want_sub[1]);
    __asm__ volatile ("fsub.s %0, %1, %2, rdn" : "=f"(r) : "f"(big_.f), "f"(one_.f));
    expect("sub rdn", r, want_sub[2]);
    __asm__ volatile ("fsub.s %0, %1, %2, rup" : "=f"(r) : "f"(big_.f), "f"(one_.f));
    expect("sub rup", r, want_sub[3]);
    __asm__ volatile ("fsub.s %0, %1, %2, rmm" : "=f"(r) : "f"(big_.f), "f"(one_.f));
    expect("sub rmm", r, want_sub[4]);

    printf("fpu %s\n", errors ? "FAILED" : "ok");
    return errors;
}
