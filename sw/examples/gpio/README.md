# 💡 GPIO Hardware Verification Test

This directory contains a bare-metal integration test for the **HORNET-RV32IMF** RISC-V core. It is designed to validate the custom Wishbone GPIO peripheral (`gpio_wb.v`) and confirm that the software driver successfully maps to the physical FPGA output pins.

## 📐 Test Architecture

This test is a classic "Blinky" application, acting as the "Hello World" of embedded hardware. It verifies the entire hardware-software stack from the C application layer down to the physical FPGA pins:

1. **Bare-Metal C Firmware:** A simple infinite loop that toggles a state variable and utilizes a blocking delay.
2. **GPIO Driver:** Writes the state variable directly to the memory-mapped GPIO base address (`0x10008020`).
3. **Wishbone Interconnect:** Routes the write transaction to the GPIO slave module.
4. **Physical Output:** The GPIO module latches the lowest bit and drives the `gpio_trigger_o` signal, which is constrained to a physical LED on the FPGA board.

```text
[ C Application (main.c) ] 
       |
       v
[ GPIO Driver (gpio.c) ] --- (Memory Write to 0x10008020)
       |
       v
[ Wishbone Interconnect ] 
       |
       v
[ Hardware (gpio_wb.v) ] --- (Drives gpio_trigger_o) ---> [ 💡 Physical LED ]
```

## 📦 Prerequisites

* **Hardware:** Nexys-4-DDR (or equivalent FPGA development board).
* **Constraints:** Ensure that `gpio_trigger_o` is correctly mapped to an LED in your constraints file.
* **Toolchain:** `riscv32-unknown-elf-gcc` for compiling the firmware.

## 🚀 Execution Commands

**1. Build the Bare-Metal Firmware**
Compile the C firmware, link the hardware driver (`gpio.c`), and generate the `memory_init.mem` file for Vivado synthesis:
```bash
make clean
make build
```

**2. Flash the FPGA**
Run synthesis and implementation in your FPGA toolchain (e.g., Vivado) and program your Nexys-4-DDR board with the resulting bitstream.

*(Note: If the system clock frequency differs significantly from the default expectations, you may need to adjust the `delay()` count in `main.c` to ensure the blinking is visible to the human eye).*

---

## 📊 Verification Results

Upon successfully programming the FPGA, the assigned LED should immediately begin toggling on and off at a steady interval. 

**Status:** ✅ **PASSING** (Visual Verification)

---

## 👤 Test Author / Credentials

* **Yusuf Tekin:** tekiny20@itu.edu.tr