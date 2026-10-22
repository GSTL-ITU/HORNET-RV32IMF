# ADR-0005: M extension

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** `mul`, `div`, `ex_stage`, `mem_stage`, `hazard_unit`
- **Follows:** PythaCore ADR-0009

## Context

The old MULDIV unit was a state machine in EX that stalled the whole
pipeline, built from a custom iterative multiplier and divider.

## Decision

PythaCore ADR-0009:

- Multiplier in two stages: operands registered at EX/MEM, one 33 x 33
  signed `*` in MEM, product into MEM/WB. A multiply is a late producer
  (one stall for a direct consumer, then forwarding from WB).
- Divider: radix-2 restoring, iterative in EX, 32 steps plus a fast path
  for division by zero and `-2^31 / -1`. It captures its operands in its
  first EX cycle without a memory wait; while busy, IF/ID and ID/EX hold
  and EX/MEM gets bubbles. It returns to idle whenever its instruction
  leaves EX (advance or flush).
- Formal uses `RISCV_FORMAL_ALTOPS`; the divider runs 3 steps under ALTOPS.

## Consequences

- `rv32um` vs. Spike, random programs with M instructions, formal with
  `isa rv32im`.
