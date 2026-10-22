# HORNET version 2: what changed and why

Version 1 of HORNET ran RV32IMF programs on the Nexys boards, but its
structure made it slow, hard to extend and wrong in corner cases. This page
lists what was found while reworking it and what version 2 does instead.
The design choices are recorded in the [ADRs](decisions/); the numbers come
from the [verification](verification/README.md) and the [Vivado builds](fpga.md).

## Pipeline and core

| Version 1 | Consequence | Version 2 |
|---|---|---|
| Register files written on the falling clock edge | half a cycle for write-back and decode; one of the reasons for 26 MHz | rising-edge register files with write-to-read bypass ([ADR-0004](decisions/0004-pipeline.md)) |
| Next-PC mux drove the instruction memory address combinationally, from several flush sources | long path into the BRAM; fetch tied to every stall source | fetch unit with request/grant/valid port and a one-entry buffer ([ADR-0003](decisions/0003-core-memory-ports.md)) |
| Flushes and stalls generated in five places (CSR unit, hazard unit, MULDIV, FPU, LSU) with different rules | hard-to-follow interactions, interrupts lost or taken twice under stalls | one hazard unit for every stall, flush, redirect and forwarding select |
| Misaligned loads and stores split into two bus accesses in hardware | extra state in EX and MEM, a load could be half done when a trap or interrupt came | misaligned accesses trap (cause 4/6) precisely; GCC uses `-mstrict-align` |
| Data requests issued from EX, results combined in MEM | memory timing spread over two stages | MEM issues, WB receives; the whole pipeline holds while a port waits |
| Every CSR instruction stalled while any CSR address matched one in flight | slow CSR code, no real ordering guarantee | CSRs read and written when the instruction leaves MEM, in program order |
| MULDIV state machine stalled the whole pipeline | every multiply took many cycles | multiplier in MEM (DSP48, one stall for a direct consumer), radix-2 divider in EX that lets older instructions drain ([ADR-0005](decisions/0005-m-extension.md)) |
| No FENCE (decoded illegal), no WFI | standard C and startup code could trap | FENCE is a no-op, FENCE.I refetches, WFI is a no-op |
| Only part of the illegal encodings detected (F instructions never illegal) | undefined behaviour on bad encodings | exact RV32IMF/Zicsr decoding, including `frm` and `mstatus.FS` |
| Tracer output gated with `~clk_i` | not usable as a verification interface | RVFI port (riscv-formal and Spike co-simulation) |

## CSRs, traps and interrupts

| Version 1 | Consequence | Version 2 |
|---|---|---|
| CSRs read in ID, written in WB | a younger instruction could see stale values | commit in MEM ([ADR-0006](decisions/0006-csr-traps-interrupts.md)) |
| `fflags` showed only the flags of the last FP instruction | software could not see an earlier overflow or invalid operation | flags travel with the instruction and accumulate when it commits |
| No `mtval`, no counters (`mcycle`, `minstret`), no `misa`, no `mstatus.FS` | standard trap handlers and `rv32mi` tests could not run | full machine-mode CSR set, `time` from the timer, debug-trigger CSRs read zero |
| Interrupts taken by flushing whichever stages were not marked "dummy" | wrong `mepc` and lost instructions under some stall patterns | the instruction in ID becomes an interrupt carrier and traps in order |
| Exceptions at different stages flushed different parts of the pipeline | imprecise traps | all traps precise; access faults (bus errors) taken in WB |

## FPU

Measured against 4.27 M TestFloat vectors (all rounding modes, [verification](verification/README.md#fpu)):

| Version 1 | Version 2 |
|---|---|
| no fused multiply-add: `fmadd`, `fmsub`, `fnmadd`, `fnmsub` were illegal and programs needed `-ffp-contract=off` | one FMA unit computes FADD, FSUB, FMUL and the four fused forms with a single rounding |
| wrong flags in about 3.5 M vectors (missing inexact, spurious underflow, no invalid on conversions) | all flags correct |
| wrong results in about 100 vectors each of FADD, FSUB, FMUL, 58 of FDIV, 3 of the integer conversions | all results correct |
| single-cycle adder behind the forwarding muxes in EX: the critical path of the core | multi-cycle units with registered results ([ADR-0007](decisions/0007-f-extension.md)) |
| classify, sign injection, min/max, compare | kept unchanged (they pass) |

## Memory, bus and peripherals

| Version 1 | Version 2 |
|---|---|
| one 480 KB dual-port memory for code and data (Von Neumann) behind Wishbone | instruction and data block RAMs on separate core ports, sizes as parameters ([ADR-0002](decisions/0002-memory-system.md)) |
| Wishbone crossbar that registered the strobe of the wrong port and had no error response | AXI4-Lite interconnect with a decode-error responder; bus errors become access faults ([ADR-0008](decisions/0008-axi4-lite-bus.md)) |
| no way to attach Vivado IP | external AXI4-Lite master port; `hornet_soc` packaged as a Vivado IP; block-design demo with an AXI GPIO |
| 1-bit write-only GPIO | 32-bit GPIO: outputs, inputs, direction, edge interrupts |
| UART without FIFOs, status bits in odd byte lanes, fixed baud rate | UART with 16-byte FIFOs, interrupts, runtime baud divisor |
| `mtime`/`mtimecmp` only | CLINT layout timer with `msip` |
| loader that reset the core when the UART saw certain bytes | UART bootloader with CRC-checked blocks, starts the resident program after one second |

## Software and flow

| Version 1 | Version 2 |
|---|---|
| `crt0` did not clear `.bss`, set `gp` or enable the FPU | one `crt0.S`, one linker script, newlib syscalls (`printf` on the UART, `malloc`) |
| a copy of a generic linker script and a different Makefile per example | two-line Makefiles including `sw/common.mk` |
| `rom_generator` binaries committed for Linux and Windows | `scripts/elf2hex.py` |
| Vivado project only, bitstreams committed | scripted batch build, GUI project script, IP packaging, all from the repository |
| no regression; RISCV-DV runs outside the repository | `make regress` in a Docker image: Spike co-simulation, random programs, TestFloat, riscv-formal, SoC programs |
| 26 MHz | 50 MHz, CPI 1.19 on rv32ui |
