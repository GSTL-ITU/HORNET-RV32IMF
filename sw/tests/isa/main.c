// ISA configuration: misa matches the extensions the program was built for
// (ISA=rv32i|rv32im|rv32imf); the instructions of every present
// extension compute, those of a missing one raise illegal-instruction
// exceptions with the instruction in mtval. The instructions are .word
// encodings so the test builds for every configuration.
#include <stdio.h>
#include <stdint.h>
#include "hornet.h"
#include "irq.h"

#ifdef __riscv_mul
#define HAS_M 1
#else
#define HAS_M 0
#endif
#ifdef __riscv_flen
#define HAS_F 1
#define FT1_CLOBBER , "ft1"
#else
#define HAS_F 0
#define FT1_CLOBBER
#endif

volatile int illegals;
volatile uint32_t last_tval;

void direct_trap_handler()
{
    if (read_csr(mcause) == 2) {
        illegals++;
        last_tval = read_csr(mtval);
    }
    write_csr(mepc, read_csr(mepc) + 4);
}

static int errors;

static void check(const char *what, uint32_t got, uint32_t want)
{
    printf("%-26s %08lx %s\n", what, (unsigned long)got, got == want ? "ok" : "FAILED");
    if (got != want)
        errors++;
}

// one instruction of an extension: a0 = a0 op a1 (or traps and leaves a0)
#define RUN(word, a, b) ({                                              \
    register uint32_t a0_ __asm__("a0") = (a);                          \
    register uint32_t a1_ __asm__("a1") = (b);                          \
    __asm__ volatile (".word " #word : "+r"(a0_) : "r"(a1_) : "memory"); \
    a0_; })

// before: the illegal-instruction count before the instruction ran
static void probe(const char *what, uint32_t word, int before, uint32_t result, int present, uint32_t want)
{
    if (present) {
        check(what, result, want);
        check("  no trap", illegals - before, 0);
    } else {
        check(what, illegals - before, 1);
        check("  mtval", last_tval, word);
    }
}

int main(void)
{
    uint32_t misa = read_csr(misa);
    uint32_t want = 0x40000100 | (HAS_M ? 1u << 12 : 0) | (HAS_F ? 1u << 5 : 0);
    printf("built for RV32I%s%s, misa %08lx\n", HAS_M ? "M" : "", HAS_F ? "F" : "", (unsigned long)misa);
    check("misa", misa, want);

    SET_MTVEC_DIRECT_MODE();

    // mul a0, a0, a1 / divu a0, a0, a1
    int before = illegals;
    uint32_t r = RUN(0x02b50533, 6, 7);
    probe("mul 6*7", 0x02b50533, before, r, HAS_M, 42);
    before = illegals;
    r = RUN(0x02b55533, 100, 7);
    probe("divu 100/7", 0x02b55533, before, r, HAS_M, 14);

    // mstatus.FS: writable with F, read-only zero without
    __asm__ volatile ("csrs mstatus, %0" :: "r"(0x6000) : "memory");
    check("mstatus.FS after set", (read_csr(mstatus) >> 13) & 3, HAS_F ? 3 : 0);

    // fmv.w.x ft1, a0 ; fadd.s ft1, ft1, ft1 (rne) ; fmv.x.w a0, ft1 in one block (ft1 is not
    // preserved across calls); without F all three trap and a0 keeps its value
    before = illegals;
    {
        register uint32_t a0_ __asm__("a0") = 0x3fc00000;  // 1.5
        __asm__ volatile (".word 0xf00500d3\n.word 0x001080d3\n.word 0xe0008553"
                          : "+r"(a0_) :: "memory" FT1_CLOBBER);
        r = a0_;
    }
    if (HAS_F) {
        check("fadd.s 1.5+1.5", r, 0x40400000);
        check("  no trap", illegals - before, 0);
    } else {
        check("F instructions trap", illegals - before, 3);
        check("  mtval", last_tval, 0xe0008553);
        check("  a0 unchanged", r, 0x3fc00000);
    }
    before = illegals;
    r = RUN(0x00302573, 0, 0);
    probe("csrr fcsr", 0x00302573, before, r, HAS_F, 0);

    printf("%s\n", errors ? "FAILED" : "PASSED");
    return errors != 0;
}
