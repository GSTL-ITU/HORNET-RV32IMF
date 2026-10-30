// Custom tests for the RISCV-DV flow (scripts/riscv_dv.py --directed).
//
// A custom test is an assembly file that includes this header, starts with
// TEST_BEGIN and ends with TEST_END. It is built with RISCV-DV's linker script
// for the ISA under test, runs on Spike and on the core testbench, and both
// traces are compared like those of the generated programs: every register
// write, fflags and memory access. A line "# requires: f" (or m) skips the
// test on a configuration without that extension.
//
// TEST_BEGIN sets a trap handler that skips the trapping instruction and
// leaves mcause in t6 (so traps appear in both traces), and turns the FPU on
// in F builds. The F macros put their operands in ft1..ft3, the result in ft0
// (or a0) and read and clear fflags into a1 after every operation, so each
// result and its flags are compared.

#define TEST_BEGIN                      \
    .section .text;                     \
    .globl _start;                      \
_start:                                 \
    la t6, trap_handler;                \
    csrw mtvec, t6;                     \
    FPU_ON;                             \
    j test_body;                        \
    .align 2;                           \
trap_handler:                           \
    csrr t6, mepc;                      \
    addi t6, t6, 4;                     \
    csrw mepc, t6;                      \
    csrr t6, mcause;                    \
    mret;                               \
test_body:

#define TEST_END                        \
    fence;                              \
    li gp, 1;                           \
    la t5, tohost;                      \
    sw gp, 0(t5);                       \
1:  j 1b;                               \
    .section .data;                     \
    .align 6; .global tohost; tohost: .dword 0; \
    .align 6; .global fromhost; fromhost: .dword 0;

#ifdef __riscv_flen
#define FPU_ON li t6, 0x2000; csrs mstatus, t6; csrwi fcsr, 0
#else
#define FPU_ON
#endif

#ifdef __riscv_flen
// load the bit pattern \v into float register \f
.macro FLI f, v
    li t0, \v
    fmv.w.x \f, t0
.endm

// \op ft0, ft1, ft2 in the five static modes and with frm = 0..4 (dynamic)
.macro FBIN op, a, b
    FLI ft1, \a
    FLI ft2, \b
    .irp rm, rne, rtz, rdn, rup, rmm
    \op ft0, ft1, ft2, \rm
    csrrw a1, fflags, zero
    .endr
    .irp frm, 0, 1, 2, 3, 4
    csrwi frm, \frm
    \op ft0, ft1, ft2
    csrrw a1, fflags, zero
    .endr
    csrwi frm, 0
.endm

// fused multiply-add family: \op ft0, ft1, ft2, ft3
.macro FTER op, a, b, c
    FLI ft1, \a
    FLI ft2, \b
    FLI ft3, \c
    .irp rm, rne, rtz, rdn, rup, rmm
    \op ft0, ft1, ft2, ft3, \rm
    csrrw a1, fflags, zero
    .endr
    .irp frm, 0, 1, 2, 3, 4
    csrwi frm, \frm
    \op ft0, ft1, ft2, ft3
    csrrw a1, fflags, zero
    .endr
    csrwi frm, 0
.endm

// one-operand operations with a rounding mode: fsqrt.s ft0, ft1
.macro FUN op, a
    FLI ft1, \a
    .irp rm, rne, rtz, rdn, rup, rmm
    \op ft0, ft1, \rm
    csrrw a1, fflags, zero
    .endr
    .irp frm, 0, 1, 2, 3, 4
    csrwi frm, \frm
    \op ft0, ft1
    csrrw a1, fflags, zero
    .endr
    csrwi frm, 0
.endm

// float to integer: fcvt.w.s a0, ft1
.macro FTOI op, a
    FLI ft1, \a
    .irp rm, rne, rtz, rdn, rup, rmm
    \op a0, ft1, \rm
    csrrw a1, fflags, zero
    .endr
    .irp frm, 0, 1, 2, 3, 4
    csrwi frm, \frm
    \op a0, ft1
    csrrw a1, fflags, zero
    .endr
    csrwi frm, 0
.endm

// integer to float: fcvt.s.w ft0, a2
.macro ITOF op, v
    li a2, \v
    .irp rm, rne, rtz, rdn, rup, rmm
    \op ft0, a2, \rm
    csrrw a1, fflags, zero
    .endr
    .irp frm, 0, 1, 2, 3, 4
    csrwi frm, \frm
    \op ft0, a2
    csrrw a1, fflags, zero
    .endr
    csrwi frm, 0
.endm
#endif
