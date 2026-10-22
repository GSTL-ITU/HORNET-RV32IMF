# ADR-0010: Peripherals and software environment

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** `rtl/soc/` peripherals, `sw/`

## Context

The old peripherals were a write-only one-bit GPIO, a UART without FIFOs
whose status bits sat in odd byte lanes, and `mtime`/`mtimecmp` without
`msip`. `crt0` did not clear `.bss`, set `gp` or enable the FPU, and every
example had its own copy of a generic linker script.

## Decision

- **Timer** (CLINT layout, base `0x2000_0000`): `msip` at `+0x0`,
  `mtimecmp` at `+0x4000`, `mtime` at `+0xBFF8`; drives MSI and MTI and
  `time` for the CSR unit.
- **UART** (`0x2001_0000`): data, status, control, baud divisor registers,
  16-byte RX and TX FIFOs, interrupt on RX not empty / TX empty (fast IRQ 0).
- **GPIO** (`0x2002_0000`): 32 outputs, 32 inputs, direction, interrupt on
  input edges (fast IRQ 1).
- One `crt0.S` (stack, `gp`, `.bss`, FPU on, trap vector, `main`, exit),
  one linker script with `IMEM`/`DMEM` regions, one `sw/common.mk` that
  every program includes, and drivers with the register maps in headers.
  The old driver function names are kept.

## Consequences

- Examples build with `make -C sw/examples/<name>` and run on the SoC
  testbench (`make sw-sim PROG=<name>`) and on the board.
