# 🫧 FPU Bubble Sort Hardware Verification Test

This directory contains a bare-metal integration test for the **HORNET-RV32IMF** RISC-V core. It is designed to validate the custom Floating-Point Unit (FPU) by stressing floating-point comparisons and memory load/store operations, using the GPIO peripheral as a physical pass/fail indicator.

## 📐 Test Architecture

This test leverages a classic Bubble Sort algorithm applied to an array of single-precision IEEE-754 floating-point numbers. It verifies that the FPU can accurately compare and swap floats in memory.

1. **Volatile Memory Access:** The `volatile float` arrays force the GCC compiler (`-O3`) to emit actual hardware FPU instructions (`flw` for floating load, `fsw` for floating store, and `fgt.s` / `fle.s` for floating comparisons) instead of optimizing the sort away at compile time.
2. **Execution Flow:** * The core initializes a set of unsorted floats and expected sorted floats.
   * The GPIO LED is driven LOW (Off) to indicate the test is running.
   * The hardware FPU sorts the array.
   * A custom memory comparison checks the result against the expected array.
3. **Physical Output:** If the array is sorted flawlessly, the GPIO driver writes a `1` to the Wishbone GPIO slave (`0x10008020`), turning the physical LED HIGH (On). The processor then safely halts in an infinite loop.

```text
[ Unsorted Float Array ] -> [ Hardware FPU (fgt.s, flw, fsw) ] -> [ Sorted Array ]
                                                                        |
                                                                [ Array Compare ]
                                                                        |
                                                                 (Match == True?)
                                                                        |
                                                             [ GPIO Driver (0x10008020) ]
                                                                        |
                                                               [ 💡 Physical LED ON ]
```

## 📦 Prerequisites

* **Hardware:** Nexys-4-DDR (or equivalent FPGA development board).
* **Constraints:** Ensure that `gpio_trigger_o` is correctly mapped to an LED in your constraints file.
* **Toolchain:** `riscv32-unknown-elf-gcc` configured with `-march=rv32imf -mabi=ilp32f` for compiling the firmware.

## 🚀 Execution Commands

**1. Build the Bare-Metal Firmware**
Compile the C firmware, link the hardware driver (`gpio.c`), and generate the `memory_init.mem` file for Vivado synthesis:
```bash
make clean
make build
```
**2. Flash the FPGA**
Run synthesis and implementation in your FPGA toolchain (e.g., Vivado) and program your Nexys-4-DDR board with the resulting bitstream.

---

## 📊 Verification Results

Upon successfully programming the FPGA, the assigned LED should immediately light up and remain on, indicating that the FPU successfully sorted the array and passed the equality check. If the LED remains off, an FPU comparison or memory alignment error has occurred.

**Status:** ✅ **PASSING** (Visual LED Verification)

---

## 👤 Test Author / Credentials

* **Yusuf Tekin:** tekiny20@itu.edu.tr