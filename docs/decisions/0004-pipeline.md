# ADR-0004: Five-stage pipeline

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** `hornet_core` and the stage modules, `hazard_unit`, register files
- **Follows:** PythaCore ADR-0007

## Context

The old pipeline flushed and stalled from several places (CSR unit,
hazard unit, multiplier, FPU, LSU), wrote the register file on the falling
clock edge, stalled every CSR instruction on CSR addresses in flight, and
resolved interrupts by flushing different stages depending on what was in
them. Branch and jump targets went combinationally from EX to the
instruction memory address.

## Decision

PythaCore ADR-0007, in Verilog-2005:

- Five stages IF ID EX MEM WB. Each pipeline register has a `valid` bit;
  a bubble is `valid = 0` and every side effect is gated by it. Reset or
  flush clears, stall holds, flush beats stall.
- Branches and JALR resolve in EX (predict not taken, 2-cycle penalty).
  JAL resolves in ID (1 cycle). Redirect priority: MEM (traps, `mret`,
  refetch) over EX over ID.
- Forwarding into EX from MEM and WB, newest first, never from x0 and never
  from a trapping instruction. The register files write on the rising edge
  and bypass a write to a read of the same register in the same cycle.
  Load-use (and every late producer, ADR-0005, ADR-0007) stalls one cycle.
- **One register namespace for hazards:** an operand is `{is_fp, index}`.
  The hazard unit and forwarding treat integer and float registers the
  same way; `x0` is zero, `f0` is a normal register.
- One hazard unit computes every stall, flush and forwarding select.

## Consequences

- The FPU (ADR-0007) and the M unit (ADR-0005) use the same hold and
  late-producer rules as in PythaCore.
- riscv-formal depths are set for five stages.
