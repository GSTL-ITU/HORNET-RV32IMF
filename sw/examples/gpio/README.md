# 💡 GPIO Hardware Verification Test

This directory contains a bare-metal integration test for the **HORNET-RV32IMF** RISC-V core. It is designed to validate the GPIO peripheral (`rtl/soc/axil_gpio.v`) and confirm that the software driver successfully maps to the physical FPGA output pins.

## 📐 Test Architecture

This test is a classic "Blinky" application, acting as the "Hello World" of embedded hardware. It verifies the entire hardware-software stack from the C application layer down to the physical FPGA pins:

1. **Bare-Metal C Firmware:** A simple infinite loop that toggles a state variable and utilizes a blocking delay.
2. **GPIO Driver:** Writes the state variable to the GPIO output register (`0x2002_0000`).
3. **AXI4-Lite Interconnect:** Routes the write transaction to the GPIO slave module.
4. **Physical Output:** The GPIO module drives `gpio_o[0]`, which `fpga/nexys4ddr/hornet_nexys4ddr.v` connects to LED0.

```text
[ C Application (main.c) ] 
       |
       v
[ GPIO Driver (gpio.c) ] --- (Memory Write to 0x20020000)
       |
       v
[ AXI4-Lite Interconnect ] 
       |
       v
[ Hardware (axil_gpio.v) ] --- (Drives gpio_o[0]) ---> [ 💡 LED0 ]
```

## 📦 Prerequisites

* **Hardware:** Nexys-4-DDR (or equivalent FPGA development board).
* **Constraints:** `fpga/nexys4ddr/nexys4ddr.xdc` maps `gpio_o[15:0]` to LED[15:0].
* **Toolchain:** the `hornet-dev` Docker image (`make docker-build` in the repository root); `sw/common.mk` uses it automatically.

## 🚀 Execution Commands

**1. Build the Bare-Metal Firmware**
Compile the C firmware with the drivers in `sw/drivers` and generate the IMEM/DMEM images in `build/`:
```bash
make
```

**2. Flash the FPGA**
From the repository root, build a bitstream with this program in the block RAMs and program the Nexys-4-DDR:
```bash
make fpga-build FPGA_PROG=sw/examples/gpio
make fpga-program FPGA_PROG=sw/examples/gpio
```

*(Note: the delay loop counts iterations; at 50 MHz the LED toggles a few times per second. `delay_ms()` in `sw/drivers/timer.h` gives exact delays).*

---

## 📊 Verification Results

Upon successfully programming the FPGA, the assigned LED should immediately begin toggling on and off at a steady interval. 

**Status:** ✅ **PASSING** (Visual Verification)

---

## 👤 Test Author / Credentials

* **Yusuf Tekin:** tekiny20@itu.edu.tr