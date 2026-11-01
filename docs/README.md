# HORNET documentation

The chapters are readable here on GitHub, and `make docs` builds them into
two PDF manuals:

| Manual | File | Contents | Read it if |
|---|---|---|---|
| **HORNET manual** | `build/docs/hornet-manual.pdf` | Part I | you want to get started quickly and do your job: set up, program, integrate, build for the FPGA |
| **HORNET student's manual** | `build/docs/hornet-student-manual.pdf` | Part I and Part II | you are a student, or want to learn how every block works and why it is designed that way |

`make docs-html` builds the student's manual as HTML (`build/docs/html/`).

## Part I: Using HORNET

| Chapter | Contents |
|---|---|
| [Introduction](introduction.md) | what HORNET is, the three ISA configurations, the two manuals, conventions |
| [Quick start](quick-start.md) | Vivado only, or Docker and Make: first bitstream, first program, first simulation |
| [Repository and environment](repository.md) | directory layout, how `make` runs the tools in Docker, build directories, the tool image, flows, contribution rules |
| [SoC](soc.md) | block diagram, memory map, interrupt sources, parameters, ports, clocking and reset |
| [Core](core.md) | stages, ISA configurations, the pipeline figure, latencies and penalties, memory ports, performance |
| [Programmer's model](programming.md) | instructions, CSRs, traps, interrupts, floating-point behaviour |
| [Peripherals](peripherals.md) | timer, UART, GPIO, system control, external AXI4-Lite port: registers; adding a peripheral |
| [Software](software.md) | build rules, memory layout, startup, C library, drivers, interrupts, tests, examples, bootloader |
| [FPGA](fpga.md) | board top, boards, Vivado flows, loading programs, Vivado IP, adding a board, results |
| [Verification](verification.md) | the verification methods and the results of this release |
| [Reference](reference.md) | parameters, make targets, RTL file index, abbreviations |
| [References](references.md) | the specifications, tools, vendor documents and books the manuals cite |

## Part II: Inside HORNET

| Chapter | Contents |
|---|---|
| [The SoC inside](soc-inside.md) | how an access travels; memories, data router, AXI4-Lite bridge and interconnect; timer, UART and GPIO internals |
| [The pipeline](pipeline.md) | the three configurations, an instruction through the pipeline, valid bits, hazards, forwarding, stalls, redirects, timing examples |
| [Instruction fetch](core-fetch.md) | fetch unit, redirects, buffer |
| [Instruction decode](core-decode.md) | control unit, legality, register files, JAL, trap selection, interrupt carriers |
| [Execute](core-execute.md) | operand capture, ALU, branches, divider algorithm, result selection |
| [Memory access and write-back](core-memory-writeback.md) | load/store unit, multiplier, commit, load alignment, access faults, RVFI |
| [CSRs, traps and interrupts](core-csr-traps.md) | the CSR unit, where traps are detected and taken, interrupt arbitration |
| [Floating-point unit](fpu.md) | binary32 in short, FMA, divide/square root, rounding, conversions |
| [Verification in depth](verification-inside.md) | testbenches, TestFloat and directed vectors, co-simulation, random programs, RISCV-DV, formal |
| [Design decisions](design-decisions.md) | index of every design decision and its reasons |
| [Update log: version 2](changelog.md) | history, what changed from version 1, bug fixes |

The figures are draw.io files in [`figures/`](figures/) (edit them with
draw.io desktop or its VS Code extension, then `make docs-figures`).
