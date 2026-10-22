# 🧪 HORNET-RV32IMF Verification & Test Suites

This directory contains the bare-metal C firmware, linker scripts, and Python verification tools used to validate the **HORNET-RV32IMF** RISC-V core. These tests cover both RTL-level simulation (Barebones) and physical FPGA hardware deployment (Nexys-4-DDR).

These test suites provide comprehensive coverage of the core's architecture, from basic peripheral Wishbone communication up to complex hardware floating-point arithmetic and system-level neural network inference.



## 📂 Test Suites Overview

The verification environment is divided into five primary test suites, each designed to stress-test specific components of the SoC:

| Test Directory | Purpose / Target Hardware | Description | Verification Method |
| :--- | :--- | :--- | :--- |
| **`gpio/`** | Basic System & GPIO | The "Hello World" of the core. Verifies the basic boot sequence and GPIO peripheral functionality by toggling a physical LED. | Visual (LED Blinking) |
| **`bubble_sort_float_fpga/`** | FPU Memory & Branching | Validates the FPU's ability to handle loads (`flw`), stores (`fsw`), and hardware comparisons by executing a Bubble Sort on the FPGA. | Visual (LED ON = Pass) |
| **`bubble_sort_float/`** | RTL Simulation (Barebones) | Optimized FPU verification for RTL simulators. Performs a floating-point bubble sort and writes status codes to the Debug Interface. | Simulation (1=Pass, 13=Fail) |
| **`uart-fpu-fpga/`** | FPU Arithmetic & UART | A closed-loop integration test. Receives floats via UART, computes hardware arithmetic (Add, Sub, Mul, Div, Sqrt), and returns results to a host PC. | Python (`fpu_test.py`) |
| **`IDS-MLP-uart-fpga/`** | Full System Integration | A high-workload application running a folded MLP neural network for Intrusion Detection. Verifies deep memory access and FPU performance. | Python (`compare_all.py`) |

## ⚙️ General Build & Execution Workflow

While each test suite contains its own detailed `README.md`, they all share a unified Bare-Metal RISC-V compilation pipeline:

1. **Compilation (`make build`):** Inside any test directory, running `make build` uses the `riscv32-unknown-elf-gcc` toolchain to compile the C and Assembly files into an `.elf` binary.
2. **Memory Generation:** The `Makefile` extracts the raw binary and passes it through the custom `rom_generator` tool to create a `memory_init.mem` file.
3. **Synthesis & Bitstream:** The `.mem` file is copied to the hardware source directory. Synthesis in Vivado embeds this program directly into the FPGA's Block RAM.
4. **Hardware Execution:** Once flashed, the core automatically boots from the reset vector (`0x00000000`), sets up the C stack, and executes the test.
5. **Simulation-Specific Result Codes:** For simulation-only tests (`sim_` prefix), the core communicates results via the **Debug Interface (0x10008010)**:
   * **0x00000001:** Test Passed.
   * **0x0000000D (13):** Test Failed (Logic/Data Mismatch).

*Note: For tests requiring UART, a host PC must be connected via a Serial/USB bridge to transmit the test vectors and verify the outputs.*

## 🗂️ Directory Structure Map
```text
test/
├── bubble_sort_float_fpga/ # FPU array sorting test (FPGA)
├── gpio/                   # Basic LED toggle test
├── IDS-MLP-uart-fpga/      # Neural Network Inference test
│   └── test/               # Contains datasets, labels, and pre-compiled bitstreams
├── sim_bubble_sort/        # RTL Simulation-only FPU test (Debug Interface)
└── uart-fpu-fpga/          # Python-driven FPU mathematical accuracy test
```

## 👤 Test Author 

Open and GitHub issue or mail directly in case of an error.

* **Yusuf Tekin:** tekiny20@itu.edu.tr