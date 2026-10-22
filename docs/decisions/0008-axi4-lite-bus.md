# ADR-0008: AXI4-Lite peripheral bus

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** `rtl/soc/`, FPGA top, Vivado IP packaging

## Context

The old SoC used Wishbone with a hand-written decoder that had no error
response for unmapped addresses and registered the strobe of the wrong
port. Students build their FPGA projects in Vivado block designs, where
Xilinx IP (AXI GPIO, AXI UART Lite, AXI Timer, ...) speaks AXI4-Lite.
PythaCore ADR-0008 keeps AXI out of the core: the core has request/grant/
valid ports and the SoC bridges to AXI.

## Decision

- The core keeps the ports of ADR-0003. In the SoC, a data-port decoder
  sends IMEM and DMEM accesses to the BRAMs and everything else through an
  **OBI-to-AXI4-Lite bridge** (one outstanding transaction, as the core
  never has more).
- An AXI4-Lite **interconnect** (1 master, N slaves, address decode,
  DECERR for holes) connects the HORNET peripherals (timer, UART, GPIO)
  and one **external `M_AXI` port** (`0x4000_0000`-`0x7FFF_FFFF`).
- Peripherals are AXI4-Lite slaves with 32-bit registers.
- `SLVERR`/`DECERR` become access faults (ADR-0003, ADR-0006).
- `hornet_soc` is packaged as a Vivado IP with an `M_AXI` interface, so it
  can sit in a block design next to Xilinx AXI IP.

## Consequences

- Peripherals can be verified with a common AXI4-Lite testbench and the
  bridge with formal protocol properties.
- Peripheral accesses take a few cycles (bridge + interconnect); memory
  accesses are not affected.
