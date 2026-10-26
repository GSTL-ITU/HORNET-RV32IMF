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

> **Note on version 2.** The version 2 rework was done by **Yusuf Tekin**
> with the support of **Claude** (Anthropic), an AI assistant. It is checked
> by simulation against Spike, TestFloat vectors, riscv-formal and builds in
> Vivado, but code written with an AI assistant can still hide mistakes that no
> test covers. If something looks wrong, please
> [report it](#-version-2-update-and-bug-reports): every bug report helps.

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
GUI: [docs/getting-started.md](docs/getting-started.md).

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

## 🐞 Version 2 Update and Bug Reports

Version 2 was written by **Yusuf Tekin** with the support of **Claude**
(Anthropic). Because a large part of it was produced with an AI assistant, we
especially want to hear about bugs. If you find one, open an
[issue](https://github.com/GSTL-ITU/HORNET-RV32IMF/issues) with:

* the program (or a few instructions) that shows it, and how you built it;
* what you expected and what happened (UART output, `build/` logs, a waveform);
* where it happened: simulation, the Nexys 4 DDR, or a block design.

Reports of wrong documentation, scripts that do not work on your machine, and
"this was hard to understand" are welcome too. Fixes go in by pull request;
`make regress` must still pass.

Everything that changed from version 1 (details and the reasons:
[docs/changes-v2.md](docs/changes-v2.md)):

<details>
<summary><b>Bug fixes</b></summary>

* **Pipeline:** register files were written on the falling clock edge (half a
  cycle for write-back and decode); now rising edge with a write-to-read bypass.
* **Pipeline:** stalls and flushes came from five places with different rules
  (CSR unit, hazard unit, MULDIV, FPU, LSU); interrupts could be lost or taken
  twice under stalls. One hazard unit now owns every stall, flush and redirect.
* **Pipeline:** misaligned loads and stores were split into two bus accesses and
  could be half done when a trap came; they now trap precisely (cause 4/6).
* **Decoder:** FENCE was illegal, WFI missing, F instructions never illegal and
  many bad encodings accepted; decoding is now exact for RV32IMF_Zicsr_Zifencei,
  including invalid rounding modes and `mstatus.FS`.
* **CSRs:** CSRs were read in ID and written in WB, so younger instructions could
  see stale values; they now commit in program order in MEM.
* **CSRs:** `fflags` held only the flags of the last FP instruction; flags now
  accumulate.
* **CSRs:** `mepc` had no reset, so an MRET before the first write could jump to
  a misaligned PC (found by riscv-formal).
* **Traps and interrupts:** `mepc` could be wrong and instructions lost when an
  interrupt hit a stall; traps are now precise and an interrupt is carried by
  the instruction in ID.
* **FPU:** wrong results in about 100 vectors each of FADD, FSUB and FMUL, 58 of
  FDIV and 3 of the integer conversions; wrong flags in about 3.5 M of 4.27 M
  TestFloat vectors (missing inexact, spurious underflow, no invalid on
  conversions). All pass now.
* **Bus:** the Wishbone crossbar registered the strobe of the wrong port and had
  no error response; unmapped addresses now return errors that become access
  faults.
* **Startup code:** `crt0` did not clear `.bss`, set `gp` or enable the FPU.
* **Loader:** the old loader reset the core when the UART saw certain bytes.

</details>

<details>
<summary><b>New features and improvements</b></summary>

* **Core:** new five-stage pipeline with forwarding, JAL resolved in ID, the
  branch target sent to the instruction memory in the same cycle; CPI 1.19 on
  rv32ui.
* **Core:** request/grant/valid memory ports with a one-entry fetch buffer; the
  core works with any number of wait states.
* **M extension:** DSP48 multiplier in MEM, radix-2 divider in EX that lets older
  instructions finish (version 1 stalled the whole pipeline for every multiply).
* **FPU:** fused multiply-add (`fmadd`, `fmsub`, `fnmadd`, `fnmsub`; version 1
  had none and needed `-ffp-contract=off`), FADD/FSUB/FMUL through the FMA,
  iterative divide and square root, new conversions, one shared rounding unit,
  registered multi-cycle results (version 1's adder was the critical path).
* **CSRs:** full machine-mode set: `misa`, `mtval`, `mcycle`, `minstret`,
  `mcountinhibit`, `time`, `mstatus.FS`, vectored `mtvec`, 16 fast interrupt
  lines.
* **Memory:** Harvard instruction and data block RAMs (sizes as parameters)
  instead of one 480 KB Von Neumann memory; no caches.
* **Bus:** AXI4-Lite interconnect for the peripherals and an external AXI4-Lite
  master port; HORNET packaged as a Vivado IP with a block-design demo.
* **Peripherals:** CLINT timer with `msip`; UART with 16-byte FIFOs, interrupts
  and a runtime baud divisor; 32-bit GPIO with direction and edge interrupts
  (version 1: 1-bit output); system control block.
* **Bootloader:** UART bootloader with CRC-checked blocks and the host script
  `scripts/hornet_load.py`; load programs without a new bitstream.
* **Clock:** 50 MHz on the Nexys 4 DDR (version 1: 26 MHz).
* **Software:** one `crt0.S`, one linker script with parameter sizes, newlib
  syscalls (`printf` on the UART, `malloc`), drivers for UART, GPIO, timer and
  interrupts, two-line Makefiles on `sw/common.mk`, new `axi_gpio` example,
  `make check` for the MLP example.
* **FPGA flow:** Vivado batch build, GUI project script, IP packaging and
  block-design script, all runnable from **Tools → Run Tcl Script** without
  arguments; default memory images so the GUI needs no compiler.
* **Verification:** Docker image with every tool; Spike co-simulation of
  riscv-tests and random programs (also with random wait states), TestFloat
  for the FPU, riscv-formal, SoC test programs, `make regress`.
* **Documentation:** [docs/](docs): getting started, architecture, peripheral
  registers, FPGA guide, verification results and design decisions (ADRs).

</details>

<details>
<summary><b>Repository layout</b></summary>

| Version 1 | Version 2 |
| :--- | :--- |
| `source/sources_1/imports/src/` (all RTL in one folder) | `rtl/core/`, `rtl/fpu/`, `rtl/soc/` |
| `source/constrs_1/`, `source/sources_1/ip/clk_wiz_0/` | `fpga/nexys4ddr/` (constraints, top, scripts; MMCM in the top instead of an `.xci`) |
| `source/sim_1/` (`barebones_top_tb.v`) | `tb/` (core, FPU and SoC testbenches) |
| `drivers/` | `sw/drivers/` |
| `rom_gen/` (`crt0.s`, `rom_generator` binaries for Linux and Windows) | `sw/common/` (`crt0.S`, `link.ld`, `syscalls.c`) and `scripts/elf2hex.py` |
| `test/<example>/` with its own linker script and Makefile | `sw/examples/<example>/` with a two-line Makefile |
| committed bitstreams (`test/IDS-MLP-uart-fpga/test/bit_streams/`) | removed; build them with `make fpga-build` or the GUI script |
| — | `sw/tests/`, `sw/bootloader/`, `fpga/ip/`, `verif/` (riscv-tests, riscv-formal), `scripts/`, `docker/`, `docs/` |

Removed RTL: `core.v`, `core_wb.v`, `barebones_wb_top.v`, `fpga_top.v`,
`forwarding_unit.v`, `hazard_detection_unit.v`, `load_store_unit.v`, `MULDIV_*`,
`MUL_DIV_out.v`, `divider_*`, `multiplier_*`, `sqrt_24.v`, the old FPU
arithmetic files, the Wishbone peripherals, `loader_wb.v`, `debug_interface_wb.v`
and `tracer.v` (replaced by the RVFI port). Kept from version 1: `ALU.v`,
`imm_decoder.v`, `fpu_decoder.v`, `fpu_sign_inj.v`, `fpu_min_max.v`,
`fpu_compare.v`, `fpu_classifier.v`. Rewritten under the same name:
`control_unit.v`, `csr_unit.v`, `fpu_top.v`.

</details>

---

## Future Plans
1. Combine every ISA generation in a single repository. 
2. Cache hierrachy.
3. Further tests to stress test the FPGA build on real hardware.

---

## 👤 Contact & Support

For technical inquiries or bug reports, please open an issue in this repository or contact the organizers:
* **Yusuf Tekin:** [tekiny20@itu.edu.tr](mailto:tekiny20@itu.edu.tr) - [GitHub Profile](https://github.com/jsphtkn)
* **Deniz Zakir Eroglu:** [eroglud20@itu.edu.tr](mailto:eroglud20@itu.edu.tr) - [GitHub Profile](https://github.com/dezariye)

---
*Developed at Istanbul Technical University. 🐝*
