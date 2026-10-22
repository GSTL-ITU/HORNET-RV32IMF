# ADR-0007: F extension and FPU

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** `rtl/fpu/`, decoder, `ex_stage`, register files, `csr_unit`

## Context

The old FPU had no fused multiply-add (`fmadd`, `fmsub`, `fnmadd`,
`fnmsub` decoded as illegal, so programs had to be built with
`-ffp-contract=off`), did not raise inexact or invalid on conversions,
kept no sticky flags, decoded unknown F encodings as legal, and ran its
single-cycle adder in EX behind the forwarding muxes (the clock limit).
PythaCore has no FPU; its ADR-0009 (M extension) gives the pattern for
long-latency units.

## Decision

- **Placement:** every FP operation executes in EX, like the divider of
  ADR-0005. Single-cycle operations (sign injection, min/max, compare,
  classify, moves) finish in their first EX cycle. Multi-cycle operations
  capture their operands in the first EX cycle without a memory wait and
  hold IF/ID and ID/EX until done; older instructions drain.
  - FMA unit (`fadd`, `fsub`, `fmul`, the four fused forms), several cycles,
    registered between unpack, multiply, align/add, normalise and round.
  - Divide and square root: iterative, one quotient/root bit per cycle.
  - Conversions: registered result (two cycles).
- **IEEE 754-2008 binary32 as the RISC-V F spec requires:** all five
  rounding modes, subnormal inputs and outputs (no flush to zero),
  canonical NaN `0x7FC00000`, tininess detected after rounding, the five
  flags. Invalid `frm` values make dynamic-rounding instructions illegal.
- **Flags** travel with the instruction and are OR-ed into `fflags` when it
  commits in MEM (ADR-0006), so a CSR read of `fflags` sees exactly the
  older instructions.
- **Register file:** 32 float registers, 3 read ports (`rs3` for the
  fused forms), one shared write port with the integer file (each
  instruction writes at most one register). `FLW`/`FSW` use the integer
  load/store path.
- Units of the old FPU that pass the TestFloat vectors are kept; the
  others are replaced.

## Consequences

- C programs can be built with the default `-ffp-contract`.
- Verification: TestFloat vectors per operation and rounding mode on the
  FPU alone, `rv32uf` and random FP streams vs. Spike on the core.
  riscv-formal has no F model; formal covers the integer side only.
