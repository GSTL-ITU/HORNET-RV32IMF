# Design decisions

Each chapter of Part II ends with a *Design decisions* section that
explains why the block is built the way it is, which alternatives were
considered, and what was wrong in version 1. This chapter is the index of
those decisions, so that a reviewer can find the reason behind any choice.
The decisions about the software, the FPGA flow and the documentation are
at the end of this chapter.

Several decisions follow the records of the PythaCore project of the same
laboratory, where the same questions came up for a smaller RV32IM core:
the request/grant/valid memory protocol, the five-stage pipeline structure,
the multiplier/divider placement, the RVFI port, and the CSR and trap
design.

| # | Decision | Alternatives considered | Chapter |
|---|---|---|---|
| D1 | Verification against independent references (Spike, TestFloat, riscv-formal, hardware results), all tools in one pinned Docker image | Vivado project with a self-checking testbench (version 1); tools installed per machine | [Verification](verification-inside.md), [Repository](repository.md#the-tool-image) |
| D2 | Harvard memory: separate instruction and data block RAMs, no caches; the data port reaches IMEM | unified memory (version 1); caches in front of DDR | [SoC inside](soc-inside.md#design-decisions) |
| D3 | Core memory ports with request/grant/valid handshake, byte enables and an error bit; one request outstanding per port | Wishbone (version 1); AXI in the core | [Core: memory ports](core.md#memory-ports), [Fetch](core-fetch.md#design-decisions) |
| D4 | Five-stage in-order pipeline, one hazard unit, rising-edge register files with bypass, JAL in ID, branches in EX, predict not taken | stalls and flushes in five modules, falling-edge register writes (version 1); branch prediction | [Pipeline](pipeline.md#design-decisions) |
| D5 | Redirect target sent to the instruction memory in the same cycle; `target + 4` computed in parallel | registered redirect (one more cycle per taken branch) | [Fetch](core-fetch.md#design-decisions) |
| D6 | One register namespace `{is_float, index}` for hazards and forwarding | separate integer and float hazard logic | [Pipeline: hazards](pipeline.md#one-register-namespace) |
| D7 | M extension: 33 × 33 multiplier in MEM, radix-2 restoring divider in EX with operand capture | multi-cycle MULDIV state machine stalling the pipeline (version 1); multiplier in EX; high-radix divider | [Execute](core-execute.md#design-decisions), [MEM/WB](core-memory-writeback.md#design-decisions) |
| D8 | Misaligned loads and stores trap | split accesses in hardware (version 1) | [Pipeline](pipeline.md#design-decisions) |
| D9 | Exact decoding of RV32I/M/F, Zicsr, Zifencei per configuration | partial decoding (version 1) | [Decode](core-decode.md#design-decisions) |
| D10 | Machine mode only; CSRs, traps and `mret` commit in MEM; interrupts enter as carriers tagged in ID; access faults in WB | CSR read in ID / write in WB and flush-based interrupts (version 1) | [CSRs and traps](core-csr-traps.md#design-decisions) |
| D11 | F extension: all FP operations in EX; one FMA unit for add, subtract, multiply and the fused forms; iterative divide/square root; registered results; full IEEE 754 behaviour; flags carried with the instruction | separate adder and multiplier without FMA, single-cycle adder in EX (version 1); flush-to-zero | [FPU](fpu.md#design-decisions) |
| D12 | ISA configurations RV32I, RV32IM, RV32IMF by the parameters `RV_M`, `RV_F`; absent hardware is not built and its instructions trap | separate source trees per configuration; a single RV32IMF core | [Pipeline: configurations](pipeline.md#the-three-configurations) |
| D13 | AXI4-Lite peripheral bus behind a bridge, one external AXI4-Lite master port, errors as access faults | Wishbone crossbar without errors (version 1); AXI4 full | [SoC inside](soc-inside.md#design-decisions) |
| D14 | RVFI retirement port with float extensions; riscv-formal with alternative M operations and an FPU stand-in | tracer gated by the inverted clock (version 1) | [MEM/WB: RVFI](core-memory-writeback.md#rvfi), [Verification: formal](verification-inside.md#formal-verification-riscv-formal) |
| D15 | CLINT-layout timer, UART with FIFOs and interrupts, 32-bit GPIO with edge interrupts, system-control block | version 1 peripherals (no FIFOs, 1-bit GPIO) | [SoC inside](soc-inside.md#design-decisions) |
| D16 | One startup file, linker script and build-rule file; images are the initial memory contents; UART bootloader with CRC and timeout | per-example copies (version 1); byte-triggered loader | [Software](#software) |
| D17 | Scripted, board-parametric FPGA flow runnable from the Vivado GUI; HORNET as a Vivado IP | committed Vivado project and bitstreams (version 1) | [FPGA flow](#fpga-flow) |
| D18 | RISCV-DV with open-source tools only (pygen, Spike, Verilator), unmodified submodule with run-time fixes | SystemVerilog generator and commercial simulator (the paper's closed-source flow) | [Verification: RISCV-DV](verification-inside.md#riscv-dv) |
| D19 | Documentation as GitHub Markdown with draw.io figures, built into two PDF manuals (for engineers and for students) with Sphinx and XeLaTeX in the same image | separate Word or LaTeX documents; one manual for every reader | [Documentation](#documentation) |

## Software

**One startup file, one linker script, one set of build rules.** Version 1
had a copy of a generic linker script and a different Makefile in every
example, and its `crt0` did not clear `.bss`, set `gp` or enable the FPU.
Version 2 has one of each; a program's Makefile is one line.

**The image is the initial memory content.** Because both memories are
initialised from the bitstream, `.data` needs no copy loop and a program
starts within a few cycles of reset.

**A bootloader with CRC and a timeout.** Version 1's loader reset the core
whenever the UART saw certain byte values, which could happen in normal
traffic. The new bootloader only listens for one second after reset,
checks every block and refuses writes over itself.

## FPGA flow

**Scripts instead of a committed project.** Version 1 shipped a Vivado
project with absolute paths, a clocking-wizard `.xci` and committed
bitstreams. Version 2 creates projects from Tcl scripts, instantiates the
MMCM directly in the RTL, and builds bitstreams on demand, so the
repository works with any Vivado installation and path.

**Runnable from the GUI without arguments.** Students who only have Vivado
can run every script with Tools → Run Tcl Script; default memory images
make a compiler unnecessary for the first bitstream.

**Board-parametric top.** All board differences (part, pins, LED and switch
counts, I/O standards) are in `fpga/<board>/`; the RTL is the same for every
board.

## Documentation

**Markdown chapters, built into PDFs.** The chapters are GitHub Markdown
with draw.io figures, so they can be read in the repository without a
build, and Sphinx with XeLaTeX in the tool image turns them into PDFs.
Version 1 had only a README.

**Two manuals from the same chapters.** Engineers who use HORNET need the
interfaces, the register maps and the flows; students need to know how
each block works and why. Part I holds the reference information and Part
II the explanations, each in its own chapters, so the same files build the
short HORNET manual (Part I) and the student's manual (Parts I and II)
with little repetition.

## Changing a decision

A decision that changes is not edited silently: the *Design decisions*
section of the chapter is updated with the new choice and the reason, the
table above is updated, and the change is recorded in the
[update log](changelog.md).
