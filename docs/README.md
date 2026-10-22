# HORNET documentation

| Start here | |
|---|---|
| [getting-started.md](getting-started.md) | Tools, first simulation, first bitstream: with Make or only the Vivado GUI |
| [architecture.md](architecture.md) | Block diagram, pipeline, FPU, CSRs and traps, memory map, performance |
| [peripherals.md](peripherals.md) | Register maps of the timer, UART, GPIO and system control |
| [fpga.md](fpga.md) | Vivado flows: batch build, GUI project, IP for block designs, bootloader, timing and resources |
| [verification/](verification/README.md) | How HORNET is verified and the current results |
| [changes-v2.md](changes-v2.md) | Problems of version 1 and how version 2 fixes them |
| [decisions/](decisions/) | Why things are built the way they are (ADRs) |
| [../sw/README.md](../sw/README.md) | Writing and building programs |

## Architecture decision records

| ADR | Decision |
|---|---|
| [0001](decisions/0001-verification-environment.md) | Verification environment: Docker image, Spike co-simulation, TestFloat, riscv-formal |
| [0002](decisions/0002-memory-system.md) | Harvard memory system without caches; memory map |
| [0003](decisions/0003-core-memory-ports.md) | Core memory ports: request/grant/valid with byte enables and errors |
| [0004](decisions/0004-pipeline.md) | Five-stage pipeline, forwarding, JAL in ID, one register namespace for hazards |
| [0005](decisions/0005-m-extension.md) | M extension: multiplier in MEM, iterative divider in EX |
| [0006](decisions/0006-csr-traps-interrupts.md) | CSRs, precise traps committed in MEM, interrupts tagged in ID |
| [0007](decisions/0007-f-extension.md) | F extension: FMA-based FPU in EX, sticky flags at commit |
| [0008](decisions/0008-axi4-lite-bus.md) | AXI4-Lite peripheral bus and external port |
| [0009](decisions/0009-rvfi-formal.md) | RVFI port and formal verification |
| [0010](decisions/0010-peripherals-software.md) | Peripherals and software environment |

The ADRs follow the decisions of the PythaCore project where the same
question came up there; each ADR names the PythaCore record it follows.

## Conventions

- Every non-trivial choice gets an ADR: copy
  [decisions/0000-template.md](decisions/0000-template.md) to the next free
  number. A changed decision gets a new record that supersedes the old one.
- RTL is plain Verilog-2005 (`make lint` checks it with
  `--language 1364-2005`); testbenches may use SystemVerilog.
- Every change to `rtl/` is checked with `make regress` before it is committed.
