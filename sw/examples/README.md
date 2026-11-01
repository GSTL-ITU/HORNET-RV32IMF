# HORNET-RV32IMF Example Programs

Bare-metal C programs for the HORNET SoC. They cover the peripherals, the FPU
and a full neural-network inference. All of them build with the shared rules
in [`sw/common.mk`](../common.mk); see [`sw/README.md`](../README.md) for the
software environment.

| Directory | Purpose | How it is checked |
| :--- | :--- | :--- |
| **`gpio/`** | "Hello World" of the board: blinks LED0 through the GPIO peripheral | LED on the board |
| **`bubble_sort_float/`** | FPU loads, stores and compares in a bubble sort | `make sim` (exit code 0 = pass) |
| **`bubble_sort_float_fpga/`** | The same sort on the board | LED0 on = pass |
| **`fpu_filter/`** | IIR filter with FPU arithmetic, prints one letter per sample | `make sim` (UART output) |
| **`uart-fpu-fpga/`** | Receives floats over UART (interrupts), returns add/sub/mul/div/sqrt | `fpu_test.py` on the host |
| **`IDS-MLP-uart-fpga/`** | Folded MLP for intrusion detection (NSL-KDD), 300 KB of weights | `make check` (simulation), `compare_all.py` (board) |
| **`axi_gpio/`** | Counts on LEDs through a Xilinx AXI GPIO on the external AXI4-Lite port | `make fpga-bd` in the repository root |

The self-checking SoC tests (interrupts, AXI faults, FPU flags, `fence.i`) are
in [`sw/tests`](../tests) and run with `make sw-tests` in the repository root.

## Build and run

```bash
cd sw/examples/gpio
make              # build/gpio_test.elf, .dump, .imem.hex, .dmem.hex
make sim          # run it on the SoC testbench (programs that end with exit())
```

On the board (Nexys 4 DDR; `BOARD=nexysvideo` for the Nexys Video; Vivado on the host), from the repository root:

```bash
make fpga-build FPGA_PROG=sw/examples/gpio      # bitstream in build/fpga/nexys4ddr/gpio/
make fpga-program FPGA_PROG=sw/examples/gpio    # JTAG
```

The program images are the initial contents of the instruction and data block
RAMs, so a new program needs a new bitstream. The UART runs at 115200 baud.

## Directory Structure Map
```text
examples/
├── axi_gpio/               # Xilinx AXI GPIO on the external port (block design)
├── bubble_sort_float/      # FPU array sorting test (simulation)
├── bubble_sort_float_fpga/ # FPU array sorting test (FPGA)
├── fpu_filter/             # IIR filter, UART output
├── gpio/                   # Basic LED toggle test
├── IDS-MLP-uart-fpga/      # Neural Network Inference test
│   └── test/               # datasets, labels, host and simulation scripts
└── uart-fpu-fpga/          # Python-driven FPU mathematical accuracy test
```

## 👤 Test Author 

Open and GitHub issue or mail directly in case of an error.

* **Yusuf Tekin:** tekiny20@itu.edu.tr
