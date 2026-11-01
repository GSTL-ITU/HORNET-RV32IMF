# Programmer's model

HORNET implements the RISC-V unprivileged ISA (RV32I with M and F
optional) [[RV-UNPRIV]](references.md#risc-v-specifications) and machine mode of the privileged
specification, version 1.12 [[RV-PRIV]](references.md#risc-v-specifications).
This chapter lists what software sees: instructions, CSRs, traps,
interrupts and the floating-point behaviour. The memory map and the
interrupt sources of the SoC are in [SoC](soc.md), the peripheral registers
in [Peripherals](peripherals.md).

## Instructions

| Group | Instructions | RV32I | RV32IM | RV32IMF |
|---|---|---|---|---|
| RV32I | LUI, AUIPC, JAL, JALR, BEQ, BNE, BLT, BGE, BLTU, BGEU, LB, LH, LW, LBU, LHU, SB, SH, SW, ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI, ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND, FENCE, ECALL, EBREAK | ✓ | ✓ | ✓ |
| Zicsr | CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI | ✓ | ✓ | ✓ |
| Zifencei | FENCE.I | ✓ | ✓ | ✓ |
| Privileged | MRET, WFI (no-op) | ✓ | ✓ | ✓ |
| M | MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU | trap | ✓ | ✓ |
| F | FLW, FSW, FMADD.S, FMSUB.S, FNMSUB.S, FNMADD.S, FADD.S, FSUB.S, FMUL.S, FDIV.S, FSQRT.S, FSGNJ.S, FSGNJN.S, FSGNJX.S, FMIN.S, FMAX.S, FCVT.W.S, FCVT.WU.S, FMV.X.W, FEQ.S, FLT.S, FLE.S, FCLASS.S, FCVT.S.W, FCVT.S.WU, FMV.W.X | trap | trap | ✓ |

Not implemented: the C (compressed), A (atomic) and D (double) extensions,
user and supervisor modes, PMP, debug mode. Every encoding outside the
table, including reserved fields, raises an illegal-instruction exception.

**Memory accesses.** Loads and stores must be naturally aligned; a
misaligned access raises a misaligned exception (GCC is called with
`-mstrict-align`). FENCE is a no-op. Code written into IMEM through the
data port (a loader, self-modifying code) runs after FENCE.I.

## CSRs

| Address | CSR | Access | Contents |
|---|---|---|---|
| `0x001`–`0x003` | `fflags`, `frm`, `fcsr` | RW (F only) | accumulated FP flags (NV DZ OF UF NX), dynamic rounding mode, both |
| `0x300` | `mstatus` | RW | MIE (3), MPIE (7), MPP = 11 (read-only), FS (14:13, F only), SD (31) |
| `0x301` | `misa` | RW, writes ignored | `0x4000_0100` + M (bit 12) + F (bit 5) |
| `0x304` | `mie` | RW | enable bits 3, 7, 11, 16–31 |
| `0x305` | `mtvec` | RW | BASE (31:2), MODE (0: direct, 1: vectored) |
| `0x310` | `mstatush` | RW, writes ignored | 0 |
| `0x320` | `mcountinhibit` | RW | CY (0), IR (2) stop `mcycle`, `minstret` |
| `0x340` | `mscratch` | RW | free for the trap handler |
| `0x341` | `mepc` | RW | PC of the trapping instruction; bits 1:0 read as 0 |
| `0x342` | `mcause` | RW | bit 31: interrupt; bits 4:0: cause |
| `0x343` | `mtval` | RW | faulting address, instruction or target (see the trap table) |
| `0x344` | `mip` | RW, writes ignored | pending bits 3, 7, 11, 16–31 (from the timer and the pins) |
| `0xB00`, `0xB80` | `mcycle[h]` | RW | 64-bit cycle counter |
| `0xB02`, `0xB82` | `minstret[h]` | RW | 64-bit retired-instruction counter |
| `0xC00`–`0xC02`, `0xC80`–`0xC82` | `cycle[h]`, `time[h]`, `instret[h]` | R | user aliases; `time` is `mtime` of the timer |
| `0xF11`–`0xF15` | `mvendorid`, `marchid`, `mimpid`, `mhartid`, `mconfigptr` | R | 0 (`mhartid`, `mimpid`: parameters) |
| `0xB03`–`0xB1F`, `0xB83`–`0xB9F`, `0x323`–`0x33F` | `mhpmcounter3..31[h]`, `mhpmevent3..31` | RW | read 0, writes ignored |
| `0x7A0`–`0x7A3` | `tselect`, `tdata1..3` | RW | read 0 (no debug triggers) |

Every other address, and a write to a read-only CSR (addresses `0xCxx`,
`0xFxx`), raises an illegal-instruction exception. CSRRS and CSRRC with
`rs1 = x0` (or immediate 0) only read. Without F, `fflags`, `frm` and
`fcsr` do not exist and `mstatus.FS` reads as 0.

**Floating-point state.** `mstatus.FS` is *Off* after reset; F
instructions and F CSRs are then illegal. The startup code `crt0.S` sets it
to *Initial*. An instruction that writes a float register or raises a flag,
or a write to an F CSR, sets FS to *Dirty* (and `mstatus.SD` reads 1).

**Counters.** `mcycle` counts every cycle, `minstret` every retired
instruction (not interrupt carriers, not trapping instructions). An
explicit write wins over the increment in the same cycle. `mcountinhibit`
stops either counter.

## Traps

| Cause | Exception | `mtval` |
|---|---|---|
| 0 | instruction address misaligned (JAL, branch, JALR target) | target address |
| 1 | instruction access fault | PC |
| 2 | illegal instruction | instruction word |
| 3 | breakpoint (EBREAK) | PC |
| 4 | load address misaligned | address |
| 5 | load access fault | address |
| 6 | store address misaligned | address |
| 7 | store access fault | address |
| 11 | environment call from M-mode (ECALL) | 0 |

All traps are precise: every older instruction has completed, no younger
one has changed any state. **Taking a trap:**

1. `mepc ← PC` of the trapping instruction (for an interrupt: of the first
   instruction that did not execute);
2. `mcause ← {interrupt, cause}`, `mtval ← tval`;
3. `mstatus.MPIE ← MIE`, `mstatus.MIE ← 0` (interrupts off in the handler);
4. execution continues at `mtvec.BASE`, or for an interrupt in vectored
   mode at `mtvec.BASE + 4 × cause`.

**`mret`** sets `MIE ← MPIE`, `MPIE ← 1` and continues at `mepc`. The
handler of an exception must advance `mepc` by 4 itself if the instruction
should not be repeated (ECALL, EBREAK, a skipped illegal instruction).

## Interrupts

An interrupt is taken when `mstatus.MIE = 1` and `mip & mie` is not zero.
The highest pending fast line (31..16) wins, then MEI (11), MSI (3) and
MTI (7). The sources and their vectors are listed in
[SoC: interrupt sources](soc.md#interrupt-sources).

The interrupt lines are levels. The handler must clear the source
(write `mtimecmp`, clear `msip`, read the UART, clear the GPIO `IP` bit)
before `mret`, otherwise the interrupt is taken again. A write to
`mstatus` or `mie` takes effect for the next instruction: a newly enabled
interrupt is taken right after the enabling instruction.

## Floating point

With `RV_F = 1`, every F instruction produces the result and the flags that
IEEE 754-2008 [[IEEE754]](references.md#arithmetic) and the RISC-V F specification require, for
all rounding modes and for subnormal numbers (checked against 4.27 million
TestFloat vectors [[TESTFLOAT]](references.md#arithmetic)). There is no flush-to-zero mode.

| `rm` | Name | Rounds to |
|---|---|---|
| 0 | RNE | nearest; on a tie, the even neighbour |
| 1 | RTZ | towards zero (truncate) |
| 2 | RDN | towards −∞ |
| 3 | RUP | towards +∞ |
| 4 | RMM | nearest; on a tie, away from zero |
| 7 | DYN | the mode in the `frm` CSR |

`rm` = 5 or 6, and DYN while `frm` holds 5, 6 or 7, are illegal.

- **Flags.** NV (invalid operation, e.g. ∞ − ∞, √−1), DZ (division by
  zero), OF (overflow), UF (underflow: a tiny, inexact result) and NX
  (inexact) accumulate in `fflags`. RISC-V never traps on them.
- **Tininess** is detected after rounding, as RISC-V specifies.
- **NaN results** are always the canonical quiet NaN `0x7FC0_0000`.
- **Float → integer conversions** of out-of-range values, ∞ and NaN return
  saturated values, with NV and without NX:

  | Input | FCVT.W.S | FCVT.WU.S |
  |---|---|---|
  | too large, +∞, NaN | `0x7FFF_FFFF` | `0xFFFF_FFFF` |
  | too small, −∞ | `0x8000_0000` | 0 (also for any negative value that does not round to 0) |
