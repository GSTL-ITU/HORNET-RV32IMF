# HORNET-RV32IMF: A RV32IMF RISC-V SoC

![Status](https://img.shields.io/badge/Release-v2.0.0-blue)
![Hardware](https://img.shields.io/badge/Target-Nexys%204%20DDR%20%7C%20Nexys%20Video-blue)
![ISA](https://img.shields.io/badge/ISA-RV32I%20%7C%20RV32IM%20%7C%20RV32IMF-orange)
![Toolchain](https://img.shields.io/badge/Vivado-2025.2-red)

**HORNET-RV32IMF** is an academic 5-stage pipelined RISC-V processor and SoC
for floating-point and Edge-AI work on Xilinx Artix-7 boards. It implements
**RV32IMF** (or, by two parameters, RV32I or RV32IM) with machine-mode CSRs,
traps and interrupts, runs bare-metal C programs, and is built so that
undergraduate students can use it in their projects: in simulation, on the
Nexys 4 DDR or Nexys Video with a script, or as an IP block in a Vivado block
design next to Xilinx AXI IP.

Version 2 (2026) is a rework of the original core: new pipeline, a
fully IEEE 754 compliant FPU with fused multiply-add, a precise CSR/trap
unit, a Harvard memory system, an AXI4-Lite bus, a verification environment
and an FPGA flow. What was wrong in version 1 and how it was fixed is listed
in the [update log](docs/changelog.md).

| Version | Branch | Release |
|---|---|---|
| **2** (this README) | [`main`](https://github.com/GSTL-ITU/HORNET-RV32IMF/tree/main) | [`v2.0.0`](https://github.com/GSTL-ITU/HORNET-RV32IMF/releases/tag/v2.0.0), with the two PDF manuals |
| 1 (unmaintained) | [`legacy`](https://github.com/GSTL-ITU/HORNET-RV32IMF/tree/legacy) | [`v1.2.0`](https://github.com/GSTL-ITU/HORNET-RV32IMF/releases/tag/v1.2.0) |

📘 **Documentation:** the [chapters](docs/README.md) are readable on GitHub,
and `make docs` builds two versions of the manual from them (the PDFs are
also attached to each [release](https://github.com/GSTL-ITU/HORNET-RV32IMF/releases)):

| Manual | Read it if |
|---|---|
| **HORNET manual** (`build/docs/hornet-manual.pdf`) | you want to get started quickly and do your job: the short version with setup, interfaces, register maps, software, FPGA flow and verification results |
| **HORNET student's manual** (`build/docs/hornet-student-manual.pdf`) | you are a student: the same pages, followed by *Inside HORNET*, which explains every block, its algorithms, how it is verified and why it is designed the way it is |

> **AI disclaimer.** The version 2 rework (RTL, verification, scripts and
> documentation) was done by **Yusuf Tekin** with the support of **Claude**
> (Anthropic), an AI assistant. It is checked by simulation against Spike,
> TestFloat vectors, riscv-formal and builds in Vivado, but code written with
> an AI assistant can still hide mistakes that no test covers. If something
> looks wrong, please [report it](#-version-2-update-and-bug-reports): every
> bug report helps. AI is only used for verification, bug detection and
> fixing, document preparation and wiring the RTL modules. Other than that,
> even though the naming and the modules are optimized to improve the
> readability of the code, the main logic stayed almost completely the same,
> just as the undergraduate students designed it.

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

### 🔧 Version 2 & Documentation
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
| **ISA** | RV32I, RV32IM or RV32IMF (parameters `RV_M`, `RV_F`), each with Zicsr and Zifencei; machine mode (M-only) |
| **Pipeline** | 5 stages (IF ID EX MEM WB), forwarding, JAL resolved in ID, branches in EX |
| **CPI** | 1.19 on rv32ui (block-RAM timing) |
| **M extension** | multiplier in MEM (DSP48), radix-2 divider in EX (35 cycles) |
| **FPU** | IEEE 754 binary32: all rounding modes, subnormals, five flags; fused multiply-add (6 cycles), divide (30 cycles) and square root (29), conversions (3) |
| **Traps** | precise; illegal instruction, ecall/ebreak, misaligned and faulting accesses, misaligned jumps |
| **Interrupts** | machine software, timer, external, 16 fast local lines; direct and vectored `mtvec` |
| **Memory** | Harvard: instruction and data block RAMs (64 KB each by default, parameters), no caches |
| **Bus** | AXI4-Lite for peripherals, plus an external AXI4-Lite master port for Vivado IP |
| **Peripherals** | CLINT timer, UART (FIFOs, interrupts, 115200 baud), 32-bit GPIO with edge interrupts, system control |
| **Clock** | 50 MHz on the Nexys 4 DDR and Nexys Video (version 1: 26 MHz) |
| **Resources** | 6.6 k LUTs, 2.8 k FFs, 6 DSP48, 32 BRAM36 (64 KB + 64 KB) on the Artix-7 100T |
| **Boot** | UART bootloader (optional): load programs without a new bitstream |

Block diagrams, pipeline and memory map: [SoC](docs/soc.md), [core and pipeline](docs/core.md).

---

## 🚀 Quick Start

### Option A: Vivado GUI only (no Docker, no Make)

1. Open Vivado 2025.2 → **Tools → Run Tcl Script** → `fpga/nexys4ddr/create_project.tcl`
   (Nexys Video: `fpga/nexysvideo/create_project.tcl`).
   This creates `build/vivado-<board>/hornet.xpr` with the default program (UART
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
GUI: [docs/quick-start.md](docs/quick-start.md).

---

## 📂 Project Structure

| Directory | Contents |
| :--- | :--- |
| [`rtl/core`](rtl/core) | the core: stages, decoder, register files, hazard unit, CSR unit, multiplier, divider |
| [`rtl/fpu`](rtl/fpu) | the FPU: FMA, divide/square root, conversions, rounding, compare/min-max/classify |
| [`rtl/soc`](rtl/soc) | SoC: memories, data router, AXI4-Lite bridge and interconnect, timer, UART, GPIO |
| [`fpga`](fpga) | board top, Nexys 4 DDR and Nexys Video constraints, Vivado scripts (batch, GUI project, IP, block design) |
| [`sw`](sw) | startup code, linker script, drivers, build rules, bootloader, tests, examples |
| [`tb`](tb), [`verif`](verif), [`scripts`](scripts) | testbenches, riscv-tests/riscv-formal, test and build scripts |
| [`docker`](docker) | the tool image |
| [`docs`](docs) | the manuals (Markdown, draw.io figures, PDF build) |

---

## ✅ Verification

Every change is checked by `make regress` (`make regress-isas` for all three
ISA configurations):

| Check | Result |
| :--- | :--- |
| riscv-tests rv32ui, rv32um, rv32uf, rv32mi against Spike, with and without random memory wait states | RV32I 56/56, RV32IM 64/64, RV32IMF 75/75 (2 skipped: no PMP, misaligned data) |
| Random programs against Spike (hazards, M, F, CSRs, traps), plain and with wait states | 200/200 per configuration |
| RISCV-DV (pygen) programs and custom tests against Spike | all pass |
| FPU alone against 4.27 M TestFloat vectors and 1.64 M directed vectors, all rounding modes | all pass (version 1: 3.56 M failures) |
| riscv-formal (RV32IM, CSRs, consistency checks) | 151/151 |
| C programs on the SoC (interrupts, AXI faults, FPU flags, fence.i, ISA configuration, bootloader, MLP) | all pass |
| Vivado: timing at 50 MHz (board top and block design) | met |

Every method, and the results for each ISA configuration: [docs/verification.md](docs/verification.md).

---

## 🐞 Version 2 Update and Bug Reports

Version 2 is a large rework (see the [AI disclaimer](#hornet-rv32imf-a-rv32imf-risc-v-soc)
at the top), so we especially want to hear about bugs. If you find one, open an
[issue](https://github.com/GSTL-ITU/HORNET-RV32IMF/issues) with:

* the program (or a few instructions) that shows it, and how you built it;
* what you expected and what happened (UART output, `build/` logs, a waveform);
* where it happened: simulation, the Nexys 4 DDR, or a block design.

Reports of wrong documentation, scripts that do not work on your machine, and
"this was hard to understand" are welcome too. Fixes go in by pull request;
`make regress` must still pass.

Everything that changed from version 1, the bug fixes, the new features, the
new repository layout and the history of the version 2 work are in the
[update log](docs/changelog.md). In short:

* **Fixed:** falling-edge register files, stalls and flushes from five places
  (lost or doubled interrupts), half-done misaligned accesses, inexact
  decoding (FENCE illegal, F never illegal), stale CSR reads, non-accumulating
  `fflags`, imprecise traps, about 3.5 M wrong FPU results and flags, a
  Wishbone crossbar without error responses, `crt0` without `.bss` clearing,
  a loader that reset the core on certain UART bytes.
* **New:** five-stage pipeline with one hazard unit (CPI 1.19), configurable
  ISA, IEEE 754 FPU with fused multiply-add, full machine-mode CSRs, Harvard
  memories, AXI4-Lite bus and external port, CLINT timer, UART with FIFOs,
  32-bit GPIO, UART bootloader, Nexys Video support, Vivado IP, a Docker
  verification environment and a full manual; 50 MHz instead of 26 MHz.

---


## 👤 Contact & Support

For technical inquiries or bug reports, please open an issue in this repository or contact the organizers:
* **Yusuf Tekin:** [tekiny20@itu.edu.tr](mailto:tekiny20@itu.edu.tr) - [GitHub Profile](https://github.com/jsphtkn)
* **Deniz Zakir Eroglu:** [eroglud20@itu.edu.tr](mailto:eroglud20@itu.edu.tr) - [GitHub Profile](https://github.com/dezariye)

---
*Developed at Istanbul Technical University. 🐝*
