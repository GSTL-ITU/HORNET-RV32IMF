# HORNET-RV32IMF: A RV32IMF RISC-V SoC

![Status](https://img.shields.io/badge/Status-v2%20(dev)-blue)
![Hardware](https://img.shields.io/badge/Target-Nexys--4--DDR%20(Artix--7%20100T)-blue)
![ISA](https://img.shields.io/badge/ISA-RV32IMF__Zicsr__Zifencei-orange)
![Toolchain](https://img.shields.io/badge/Vivado-2025.2-red)

**HORNET-RV32IMF** is an academic 5-stage pipelined RISC-V processor and SoC
for floating-point and Edge-AI work on Xilinx Artix-7 boards. It implements
**RV32IMF** with machine-mode CSRs, traps and interrupts, runs bare-metal C
programs, and is built so that undergraduate students can use it in their
projects: in simulation, on the Nexys 4 DDR with a script, or as an IP block
in a Vivado block design next to Xilinx AXI IP.

Version 2 (2026) is a rework of the original core: new pipeline, a
fully IEEE 754 compliant FPU with fused multiply-add, a precise CSR/trap
unit, a Harvard memory system, an AXI4-Lite bus, a verification environment
and an FPGA flow. What was wrong in version 1 and how it was fixed is listed
in [docs/changes-v2.md](docs/changes-v2.md).

---

## 👥 Contributors & Research

This project is the result of collaborative engineering at the **Istanbul Technical University (ITU)** and the **GSTL Lab**.

### 🎓 Academic Advisor
* **Prof. Dr. Sıddıka Berna Örs Yalçın** - [ITU Academic Profile](https://web.itu.edu.tr/~orssi/)

### 🏛️ Core Creators
* **Yavuz Selim Tozlu** - [GitHub](https://github.com/yavuz650)
* **Yasin Yılmaz** - [GitHub](https://github.com/yasinxyz)

### 📐 FPU Design & Implementation
* **Salih Daysal**
* **Mehmet Emin Tuzcu**

### 🧪 Verification
* **Deniz Zakir Eroglu** - [GitHub](https://github.com/dezariye)
* **Mete Kaan Özden** - [GitHub](https://github.com/mkozden)

### ✏️ Organization
* **Deniz Zakir Eroglu** - [GitHub](https://github.com/dezariye)
* **Yusuf Tekin** - [GitHub](https://github.com/jsphtkn)

### 🔧 Version 2 (pipeline, FPU, CSR unit, SoC and bus, verification, FPGA flow)
* **Yusuf Tekin** - [GitHub](https://github.com/jsphtkn)

### 📎 Projects
Projects built on HORNET:

| Project | People | |
| :--- | :--- | :--- |
| HORNET for AI applications | **Yusuf Tekin** & **Ahmet Tolga Özkan** | 🔗 **[HORNET-RV32IMF-For-AI-Applications](https://github.com/GSTL-ITU/HORNET-RV32IMF-For-AI-Applications)** |
| Intrusion detection (NSL-KDD) with a folded MLP, in this repository | **Yusuf Tekin** | [sw/examples/IDS-MLP-uart-fpga](sw/examples/IDS-MLP-uart-fpga) |

Did you build something on HORNET? Add it to this table with a pull request.

### 📚 Academic Publications
The initial design of Hornet core is detailed in the following conference paper:
> Y. S. Tozlu, Y. Yilmaz, B. Ors, “Design and Implementation Of a 32-Bit RISC-V Core”, 12th International Conference on Electrical and Electronics Engineering (ELECO), 2021. 

The verification methodologies used in this core are detailed in the following conference paper:
> D. Z. Eroglu, M. K. Ozden, B. Ors, “Creating Verification Environment Using RISCV-DV With Open and Closed Source Tools”, 9th International Symposium on Multidisciplinary Studies and Innovative Technologies (ISMSIT), 2025.

---

## ⚙️ Hardware Specifications

| Parameter | Specification |
| :--- | :--- |
| **ISA** | RV32IMF_Zicsr_Zifencei, machine mode (M-only) |
| **Pipeline** | 5 stages (IF ID EX MEM WB), forwarding, JAL resolved in ID, branches in EX |
| **CPI** | 1.19 on rv32ui (block-RAM timing) |
| **M extension** | multiplier in MEM (DSP48), radix-2 divider in EX (34 cycles) |
| **FPU** | IEEE 754 binary32: all rounding modes, subnormals, five flags; fused multiply-add (6 cycles), divide and square root (up to 29 cycles), conversions (3 cycles) |
| **Traps** | precise; illegal instruction, ecall/ebreak, misaligned and faulting accesses, misaligned jumps |
| **Interrupts** | machine software, timer, external, 16 fast local lines; direct and vectored `mtvec` |
| **Memory** | Harvard: instruction and data block RAMs (64 KB each by default, parameters), no caches |
| **Bus** | AXI4-Lite for peripherals, plus an external AXI4-Lite master port for Vivado IP |
| **Peripherals** | CLINT timer, UART (FIFOs, interrupts, 115200 baud), 32-bit GPIO with edge interrupts, system control |
| **Clock** | 50 MHz on the Nexys 4 DDR (version 1: 26 MHz) |
| **Resources** | 6.6 k LUTs, 2.8 k FFs, 6 DSP48, 32 BRAM36 (64 KB + 64 KB) on the Artix-7 100T |
| **Boot** | UART bootloader (optional): load programs without a new bitstream |

Block diagram, pipeline and memory map: [docs/architecture.md](docs/architecture.md).

---

## 🚀 Quick Start

### Option A: Vivado GUI only (no Docker, no Make)

1. Open Vivado 2025.2 → **Tools → Run Tcl Script** → `fpga/nexys4ddr/create_project.tcl`.
   This creates `build/vivado/hornet.xpr` with the default program (UART
   bootloader and an LED blink).
2. **Generate Bitstream**, then **Open Hardware Manager → Program Device**.
3. LED0 blinks. Load your own programs over the USB-UART with the bootloader:
   `python3 scripts/hornet_load.py --port /dev/ttyUSB1 <program.elf>` and press
   the reset button.

For a block design with Xilinx AXI IP, run `fpga/ip/bd_demo.tcl` the same
way: it packages HORNET as an IP and creates a block design with an AXI GPIO
on the LEDs ([docs/fpga.md](docs/fpga.md)).

### Option B: Make (simulation, software, FPGA)

```bash
make docker-build                          # once: tools in a Docker image (Verilator, GCC, Spike, ...)
make -C sw/tests/hello sim                 # run a C program on the SoC in simulation
make fpga-build FPGA_PROG=sw/examples/gpio # bitstream with that program in the block RAMs
make fpga-program FPGA_PROG=sw/examples/gpio
```

`make help` lists everything. Writing your own program:
[sw/README.md](sw/README.md). The full walk-through, also for Windows and the
GUI: [docs/getting-started.md](docs/getting-started.md).

---

## 📂 Project Structure

| Directory | Contents |
| :--- | :--- |
| [`rtl/core`](rtl/core) | the core: stages, decoder, register files, hazard unit, CSR unit, multiplier, divider |
| [`rtl/fpu`](rtl/fpu) | the FPU: FMA, divide/square root, conversions, rounding, compare/min-max/classify |
| [`rtl/soc`](rtl/soc) | SoC: memories, data router, AXI4-Lite bridge and interconnect, timer, UART, GPIO |
| [`fpga`](fpga) | Nexys 4 DDR top, constraints, Vivado scripts (batch, GUI project, IP, block design) |
| [`sw`](sw) | startup code, linker script, drivers, build rules, bootloader, tests, examples |
| [`tb`](tb), [`verif`](verif), [`scripts`](scripts) | testbenches, riscv-tests/riscv-formal, test and build scripts |
| [`docker`](docker) | the tool image |
| [`docs`](docs) | documentation, design decisions (ADRs), verification results |

---

## ✅ Verification

Every change is checked by `make regress`:

| Check | Result |
| :--- | :--- |
| riscv-tests rv32ui, rv32um, rv32uf, rv32mi against Spike, with and without random memory wait states | 75/75 (2 skipped: no PMP, misaligned data) |
| Random RV32IMF programs against Spike (hazards, FPU, CSRs, traps), plain and with wait states | all pass |
| FPU alone against 4.27 M TestFloat vectors, all rounding modes | all pass (version 1: 3.56 M failures) |
| riscv-formal (RV32IM, CSRs, consistency checks) | 151/151 |
| C programs on the SoC (interrupts, AXI faults, FPU flags, fence.i, bootloader, MLP) | all pass |
| Vivado: timing at 50 MHz (board top and block design) | met |

Details and numbers: [docs/verification/README.md](docs/verification/README.md).

---

## 👤 Contact & Support

For technical inquiries or bug reports, please open an issue in this repository or contact the organizers:
* **Yusuf Tekin:** [tekiny20@itu.edu.tr](mailto:tekiny20@itu.edu.tr) - [GitHub Profile](https://github.com/jsphtkn)
* **Deniz Zakir Eroglu:** [eroglud20@itu.edu.tr](mailto:eroglud20@itu.edu.tr) - [GitHub Profile](https://github.com/dezariye)

---
*Developed at Istanbul Technical University. 🐝*
