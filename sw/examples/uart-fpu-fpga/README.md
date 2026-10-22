# 🧪 FPU & UART Hardware Verification Test

This directory contains an integration and verification test for the **HORNET-RV32IMF** RISC-V core. It validates the custom hardware Floating-Point Unit (FPU) and the interrupt-driven UART receiver/transmitter by computing IEEE-754 single-precision floating-point arithmetic on the FPGA and verifying it against a host PC.

## 📐 Test Architecture

The test operates in a closed-loop system between a host PC and the FPGA:

1. **Host PC (Python):** Generates test vectors containing three IEEE-754 32-bit floats (`A`, `B`, `C`). These are packed into raw bytes (little-endian) and sent over UART.
2. **FPGA (Bare-Metal C):** The core receives the 12 bytes via Fast Interrupts (IRQ), reassembles them into floats, and pushes them through the hardware FPU to calculate:
   * Addition (`fadd.s`): $A + B$
   * Subtraction (`fsub.s`): $A - B$
   * Multiplication (`fmul.s`): $A \times C$
   * Division (`fdiv.s`): $A \div C$
   * Square Root (`fsqrt.s`): $\sqrt{A}$
3. **Host PC Verification:** The FPGA transmits the 5 resulting floats (20 bytes) back to the PC. The Python script unpacks them and uses a tolerance-based comparison (`math.isclose`) to verify the hardware's accuracy against standard x86/Python arithmetic.

```text
[ Host PC (fpu_test.py) ]                             [ FPGA (HORNET-RV32IMF) ]
       |                                                      |
       |--- 1. TX: struct.pack('<3f', A, B, C) (12B) -------->|  UART RX Interrupt
       |                                                      |  Reassemble Floats
       |                                                      |  Execute FPU Instructions
       |<-- 2. RX: struct.unpack('<5f', ...) (20B) -----------|  UART TX Polling
       |
  Verify against math.isclose()
```

## 📦 Prerequisites

The host script relies on standard Python 3 libraries (`struct`, `math`, `argparse`, `time`) and requires the `pyserial` package to interface with the COM port.

Install the required dependency via pip:
```bash
pip install pyserial
```

## 🚀 Execution Commands

**1. Build the Bare-Metal Firmware**
Compile the C firmware, link the hardware drivers (`uart.c`, `irq.c`), and generate the `memory_init.mem` file for Vivado synthesis:
```bash
make clean
make build
```

**2. Flash the FPGA**
Run synthesis and implementation in your FPGA toolchain (e.g., Vivado) and program your Nexys-4-DDR board with the resulting bitstream.

**3. Run the Verification Script**
Once the FPGA is powered and programmed, execute the Python script. Be sure to specify the correct serial port for your system (e.g., `/dev/ttyUSB1` for Linux, `COM3` for Windows):
```bash
python3 fpu_test.py --port /dev/ttyUSB1 --baud 115200
```

---

## 📊 Verification Results

The FPU successfully executes standard fractions, clean integers, negative floats, large floats, and zero-value edge cases with precision matching the host PC. 

**Status:** ✅ **PASSING**

```text
--- Test Case 1 ---
Sending:  A = 15.5, B = 4.25, C = 2.0
✅ A + B  : FPGA = 19.75000     | Expected = 19.75000    
✅ A - B  : FPGA = 11.25000     | Expected = 11.25000    
✅ A * C  : FPGA = 31.00000     | Expected = 31.00000    
✅ A / C  : FPGA = 7.75000      | Expected = 7.75000     
✅ sqrt(A): FPGA = 3.93700      | Expected = 3.93700     
Result: ALL PASS

--- Test Case 2 ---
Sending:  A = 144.0, B = 50.0, C = 12.0
✅ A + B  : FPGA = 194.00000    | Expected = 194.00000   
✅ A - B  : FPGA = 94.00000     | Expected = 94.00000    
✅ A * C  : FPGA = 1728.00000   | Expected = 1728.00000  
✅ A / C  : FPGA = 12.00000     | Expected = 12.00000    
✅ sqrt(A): FPGA = 12.00000     | Expected = 12.00000    
Result: ALL PASS

--- Test Case 3 ---
Sending:  A = 0.854, B = -0.122, C = 1.5
✅ A + B  : FPGA = 0.73200      | Expected = 0.73200     
✅ A - B  : FPGA = 0.97600      | Expected = 0.97600     
✅ A * C  : FPGA = 1.28100      | Expected = 1.28100     
✅ A / C  : FPGA = 0.56933      | Expected = 0.56933     
✅ sqrt(A): FPGA = 0.92412      | Expected = 0.92412     
Result: ALL PASS

--- Test Case 4 ---
Sending:  A = 9999.9, B = 1111.1, C = 3.33
✅ A + B  : FPGA = 11111.00000  | Expected = 11111.00000 
✅ A - B  : FPGA = 8888.80078   | Expected = 8888.80000  
✅ A * C  : FPGA = 33299.66797  | Expected = 33299.66700 
✅ A / C  : FPGA = 3002.97314   | Expected = 3002.97297  
✅ sqrt(A): FPGA = 99.99950     | Expected = 99.99950    
Result: ALL PASS

--- Test Case 5 ---
Sending:  A = 0.0, B = 0.0, C = 1.0
✅ A + B  : FPGA = 0.00000      | Expected = 0.00000     
✅ A - B  : FPGA = 0.00000      | Expected = 0.00000     
✅ A * C  : FPGA = 0.00000      | Expected = 0.00000     
✅ A / C  : FPGA = 0.00000      | Expected = 0.00000     
✅ sqrt(A): FPGA = 0.00000      | Expected = 0.00000     
Result: ALL PASS
```

## 👤 Test Author 

Open and GitHub issue or mail directly in case of an error.

* **Yusuf Tekin:** tekiny20@itu.edu.tr
