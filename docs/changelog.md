# Update log: version 2

Version 1 of HORNET ran RV32IMF programs on the Nexys boards, but its
structure made it slow (26 MHz), hard to extend and wrong in corner cases.
Version 2 (2026) reworks the whole design. This chapter lists what was
found in version 1, what version 2 does instead, and the history of the
version 2 work. The reasons are in the *Design decisions* sections, indexed
in [Design decisions](design-decisions.md).

## History

The first HORNET core was designed by Yavuz Selim Tozlu and Yasin Yılmaz
(ELECO 2021 [[ELECO21]](references.md#hornet-publications)), with an FPU by Salih Daysal and Mehmet Emin Tuzcu. Deniz Zakir
Eroğlu and Mete Kaan Özden built a RISCV-DV verification environment for it
(ISMSIT 2025 [[ISMSIT25]](references.md#hornet-publications)) that found several FPU bugs. Version 2 is a rework of the whole
design by Yusuf Tekin: a new pipeline, an IEEE-compliant FPU with fused
multiply-add, a precise trap unit, a Harvard memory system, an AXI4-Lite bus,
a scripted verification environment and FPGA flow, and the manuals.

Version 1 stays available, unchanged, on the `legacy` branch
(<https://github.com/GSTL-ITU/HORNET-RV32IMF/tree/legacy>) and as release `v1.2.0`; the paths in
[Repository layout](#repository-layout) below refer to it.

## Version 2.0 at a glance

| | Version 1 | Version 2 |
|---|---|---|
| ISA | RV32IMF (F incomplete: no fused multiply-add) | RV32I, RV32IM or RV32IMF (parameters), Zicsr, Zifencei, full F |
| Pipeline | five stages, falling-edge register files, stalls from five modules | five stages, rising-edge register files, one hazard unit |
| Clock (Nexys 4 DDR) | 26 MHz | 50 MHz |
| CPI (rv32ui) | — | 1.19 |
| FPU errors on 4.27 M TestFloat vectors | 3 560 239 (results and flags) | 0 |
| Memory | one 480 KB Von Neumann memory behind Wishbone | Harvard instruction and data block RAMs, sizes as parameters |
| Bus | Wishbone, no error responses | AXI4-Lite, errors become precise access faults, external port for Vivado IP |
| Peripherals | 1-bit GPIO, UART without FIFOs, timer without `msip` | CLINT timer, UART with FIFOs and interrupts, 32-bit GPIO with edge interrupts, system control |
| Boards | Nexys 4 DDR (Vivado project) | Nexys 4 DDR, Nexys Video (scripts), Vivado IP and block-design demo |
| Verification | RISCV-DV outside the repository | Spike co-simulation, random programs, RISCV-DV, TestFloat, directed FPU vectors, riscv-formal, SoC tests, all in `make` |
| Documentation | README | the HORNET manual and the student's manual (Markdown and PDF) |

## Bug fixes

| Area | Version 1 | Consequence | Version 2 |
|---|---|---|---|
| Pipeline | register files written on the falling clock edge | half a cycle for write-back and decode; one reason for 26 MHz | rising-edge register files with write-to-read bypass |
| Pipeline | stalls and flushes generated in five places (CSR unit, hazard unit, MULDIV, FPU, LSU) with different rules | interrupts lost or taken twice under some stall patterns | one hazard unit for every stall, flush, redirect and forwarding select |
| Pipeline | misaligned loads and stores split into two bus accesses | a load could be half done when a trap or interrupt came | misaligned accesses trap precisely (cause 4/6) |
| Pipeline | next-PC multiplexer drove the instruction-memory address combinationally from several flush sources | long path into the BRAM; fetch tied to every stall source | fetch unit with request/grant/valid port and a one-entry buffer |
| Decoder | FENCE decoded as illegal, no WFI | standard startup code could trap | FENCE is a no-op, FENCE.I refetches, WFI is a no-op |
| Decoder | only part of the illegal encodings detected, F instructions never illegal | undefined behaviour on bad encodings | exact decoding including `rm`, `frm` and `mstatus.FS` |
| CSRs | read in ID, written in WB | a younger instruction could see a stale value | read and written in MEM, in program order |
| CSRs | every CSR instruction stalled while any CSR address in flight matched | slow CSR code, no real ordering guarantee | no address matching needed |
| CSRs | `fflags` held only the flags of the last FP instruction | an earlier overflow or invalid operation was lost | flags accumulate at commit |
| CSRs | no `mtval`, counters, `misa`, `mstatus.FS` | standard trap handlers and `rv32mi` could not run | full machine-mode CSR set |
| CSRs | `mepc` had no reset | an `mret` before the first write could jump to a misaligned PC (found by riscv-formal) | `mepc[1:0]` read as zero |
| Traps | interrupts taken by flushing the stages not marked "dummy"; different exceptions flushed different stages | wrong `mepc`, lost instructions, imprecise traps | interrupt carriers in ID; all traps precise |
| FPU | no fused multiply-add | programs needed `-ffp-contract=off` | FMADD, FMSUB, FNMSUB, FNMADD |
| FPU | wrong results in about 100 vectors each of FADD, FSUB, FMUL, 58 of FDIV, 3 of the integer conversions | wrong numbers | all correct |
| FPU | wrong flags in about 3.5 M of 4.27 M vectors (missing inexact, spurious underflow, no invalid on conversions) | wrong `fflags` | all correct |
| FPU | dynamic rounding mode hardwired; wrong GRS rounding in RTZ/RDN/RUP; wrong overflow/underflow rounding; imprecise subnormal divide and square root (found by the RISCV-DV paper) | wrong results in those modes and ranges | all correct (1.64 M directed vectors) |
| FPU | single-cycle adder behind the forwarding multiplexers | the critical path of the core | multi-cycle units with registered results |
| Bus | Wishbone crossbar registered the strobe of the wrong port and had no error response | wrong accesses, silent failures on unmapped addresses | AXI4-Lite with decode errors; bus errors become access faults |
| Software | `crt0` did not clear `.bss`, set `gp` or enable the FPU | uninitialised globals, slow small-data access, traps on FP code | new `crt0.S` |
| Loader | reset the core when the UART saw certain bytes | random resets during normal UART traffic | bootloader that listens for one second after reset, CRC-checked blocks |
| Tracer | output gated with the inverted clock | not usable as a verification interface | RVFI port |

## New features and improvements

- **Core:** new five-stage pipeline with forwarding of integer and float
  registers in one namespace, JAL resolved in ID, the redirect target sent
  to memory in the same cycle; CPI 1.19 on rv32ui.
- **Configurable ISA:** RV32I, RV32IM and RV32IMF from the same RTL
  (`RV_M`, `RV_F`); `ISA=` selects the configuration for every flow.
- **Memory ports:** request/grant/valid with byte enables and errors; the
  core works with any number of wait states.
- **M extension:** DSP multiplier in MEM, radix-2 divider in EX that lets
  older instructions finish (version 1 stalled the whole pipeline for every
  multiply).
- **FPU:** fused multiply-add for FADD/FSUB/FMUL and the fused forms with a
  single rounding, iterative divide and square root, new conversions, one
  shared rounding module, registered results, IEEE 754 flags and subnormals.
- **CSRs and traps:** full machine-mode set, `misa`, `mtval`, 64-bit
  `mcycle`/`minstret`, `mcountinhibit`, `time`, `mstatus.FS`, vectored
  `mtvec`, 16 fast interrupt lines, precise traps.
- **SoC:** Harvard instruction and data block RAMs with parameter sizes,
  AXI4-Lite interconnect, external AXI4-Lite master port.
- **Peripherals:** CLINT timer with `msip`; UART with 16-byte FIFOs,
  interrupts and a runtime baud divisor; 32-bit GPIO with direction and
  edge interrupts; system-control block.
- **Bootloader:** UART bootloader and host script `hornet_load.py`, also
  for unattended runs (`make fpga-run`).
- **Software:** one `crt0.S`, one linker script, newlib system calls
  (`printf` on the UART, `malloc`), drivers for UART, GPIO, timer and
  interrupts, one-line Makefiles on `sw/common.mk`, programs outside the
  repository, per-ISA builds.
- **FPGA flow:** Vivado batch build, GUI project script, IP packaging and
  block-design script, all runnable without arguments; default memory
  images; board-parametric top for the Nexys 4 DDR and the Nexys Video;
  50 MHz.
- **Verification:** Docker image with every tool; VS Code Dev Container;
  Spike co-simulation of riscv-tests and random programs, also with random
  wait states; RISCV-DV with open-source tools; TestFloat and directed
  vectors for the FPU; riscv-formal; SoC test programs; per-ISA regressions.
- **Documentation:** two manuals from the same Markdown chapters with
  draw.io figures, readable on GitHub and built as PDFs (`make docs`): the
  HORNET manual for engineers and the student's manual, which adds how
  every block works and why.

## Repository layout

| Version 1 | Version 2 |
|---|---|
| `source/sources_1/imports/src/` (all RTL in one folder) | `rtl/core/`, `rtl/fpu/`, `rtl/soc/` |
| `source/constrs_1/`, `source/sources_1/ip/clk_wiz_0/` | `fpga/<board>/` (constraints, scripts); MMCM in the top instead of an `.xci` |
| `source/sim_1/` (`barebones_top_tb.v`) | `tb/` (core, FPU and SoC testbenches) |
| `drivers/` | `sw/drivers/` |
| `rom_gen/` (`crt0.s`, `rom_generator` binaries for Linux and Windows) | `sw/common/` (`crt0.S`, `link.ld`, `syscalls.c`) and `scripts/elf2hex.py` |
| `test/<example>/` with its own linker script and Makefile | `sw/examples/<example>/` with a one-line Makefile |
| committed bitstreams | removed; built with `make fpga-build` or the GUI script |
| — | `sw/tests/`, `sw/bootloader/`, `fpga/ip/`, `verif/`, `scripts/`, `docker/`, `.devcontainer/`, `docs/` |

Removed RTL: `core.v`, `core_wb.v`, `barebones_wb_top.v`, `fpga_top.v`,
`forwarding_unit.v`, `hazard_detection_unit.v`, `load_store_unit.v`,
`MULDIV_*`, `MUL_DIV_out.v`, `divider_*`, `multiplier_*`, `sqrt_24.v`, the old
FPU arithmetic files, the Wishbone peripherals, `loader_wb.v`,
`debug_interface_wb.v` and `tracer.v` (replaced by the RVFI port). Kept from
version 1: `ALU.v`, `imm_decoder.v`, `fpu_decoder.v`, `fpu_sign_inj.v`,
`fpu_min_max.v`, `fpu_compare.v`, `fpu_classifier.v`. Rewritten under the
same name: `control_unit.v`, `csr_unit.v`, `fpu_top.v`.

## History of the version 2 work

| Date | Change |
|---|---|
| 2026-10-22 | Repository restructured (`rtl/`, `fpga/`, `tb/`, `sw/`); generated binaries and bitstreams removed; riscv-tests and riscv-formal as submodules |
| 2026-10-22 | Docker image with Verilator, RISC-V GCC, Spike, TestFloat, OSS CAD Suite |
| 2026-10-22 | New five-stage pipeline, CSR unit, traps and interrupts |
| 2026-10-22 | Core testbench, riscv-tests runner with Spike comparison, random programs |
| 2026-10-22 | IEEE 754 FPU with fused multiply-add; registered multi-cycle results; formal stand-in |
| 2026-10-22 | Harvard SoC with AXI4-Lite peripherals; SoC testbench; software environment |
| 2026-10-22 | RVFI CSR ports; `mepc[1:0]` read as zero (formal finding); redirect `target + 4` in parallel |
| 2026-10-22 | riscv-formal on RVFI: 151/151 checks |
| 2026-10-22 | Nexys 4 DDR flow, Vivado batch/GUI scripts, IP packaging, block-design demo, UART bootloader |
| 2026-10-26 | Directed FPU vectors for the version 1 bugs of the RISCV-DV paper |
| 2026-10-26 | Programs outside the repository; rebuild on layout changes |
| 2026-10-26 | Board-parametric FPGA flow, Nexys Video, unattended runs over the UART |
| 2026-10-30 | Configurable ISA (RV32I, RV32IM, RV32IMF) with `RV_M`/`RV_F`, per-ISA verification, VS Code Dev Container |
| 2026-10-30 | RISCV-DV flow with pygen, Spike and trace CSV comparison |
| 2026-10-31 | This manual: chapters per block, draw.io figures, PDF build (`make docs`) |
| 2026-11-01 | Two manuals from the same chapters: the HORNET manual and the student's manual; table and code layout of the PDFs |
