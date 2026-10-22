# ADR-0002: Harvard memory system without caches

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** `rtl/soc/`, linker script, FPGA top
- **Follows:** PythaCore ADR-0002 (memories are not reset), ADR-0004, ADR-0008

## Context

The old SoC had one dual-port Wishbone memory for code and data (Von
Neumann, 480 KB, combinational address path into the BRAM) behind a
hand-written crossbar. Memory accesses from the data port and the
instruction port were not independent, and the memory size and timing
limited the clock to about 26 MHz. Students load programs by rebuilding the
bitstream with an initialised BRAM.

## Options considered

1. **Unified memory** (as before).
2. **Harvard: separate instruction and data block RAMs**, both initialised
   from the program image, each on its own core port.
3. **Caches in front of external memory** (DDR).

## Decision

Option 2, no caches.

| Region | Base | Default size | Contents |
|---|---|---|---|
| IMEM | `0x0000_0000` | 64 KB | `.text`, `.rodata` (reset vector at the base) |
| DMEM | `0x1000_0000` | 64 KB | `.data`, `.sdata`, `.bss`, heap, stack |
| Peripherals | `0x2000_0000` | | AXI4-Lite (ADR-0008) |
| External AXI4-Lite | `0x4000_0000` - `0x7FFF_FFFF` | | `M_AXI` port of the SoC for Vivado IP |

- The instruction port reaches IMEM only. The data port reaches DMEM, the
  AXI4-Lite bus and the second port of IMEM, so constants in `.rodata`
  stay in IMEM and a loader can write programs (true dual-port BRAM).
- Both memories are synchronous block RAMs that always grant and answer
  one cycle later (PythaCore ADR-0008), with no reset (ADR-0002). Sizes
  are parameters.
- Accesses outside a mapped region answer with an error (access fault).

## Consequences

- The linker script places `.data` at its run address in DMEM; the DMEM
  image is generated from the ELF, so no copy loop is needed at boot.
  `.bss` is cleared by `crt0`.
- A program change needs a new bitstream, or `updatemem` on an existing
  one (`make fpga-update`), or the UART loader once it exists.
