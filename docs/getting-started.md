# Getting started

There are two ways to work with HORNET. **Option A** needs only Vivado and
puts a working system on the Nexys 4 DDR or the Nexys Video. **Option B** adds the Docker image
with the compiler, the simulators and the verification tools, and drives
everything with `make`.

## Option A: Vivado only

Requirements: Vivado 2025.2 (any recent version should work), a Nexys 4 DDR
(Artix-7 100T) or a Nexys Video (Artix-7 200T) and its USB cables (on the
Nexys Video the UART has its own micro-USB port).

1. Start Vivado. **Tools → Run Tcl Script…** and select
   `fpga/nexys4ddr/create_project.tcl` (Nexys Video: `fpga/nexysvideo/create_project.tcl`)
   from this repository.
   The script creates `build/vivado-<board>/hornet.xpr` and opens it. It contains all
   RTL, the constraints and the default program images
   (`fpga/default/`: UART bootloader + LED blink).
2. **Generate Bitstream** (about 5 minutes).
3. **Open Hardware Manager → Open Target → Auto Connect → Program Device.**
   LED0 blinks.

The bootloader listens on the USB-UART for one second after each press of
the **CPU_RESET** button. To run another program:

```bash
pip install pyserial pyelftools
python3 scripts/hornet_load.py --port /dev/ttyUSB1 --term sw/examples/axi_gpio/build/axi_gpio.elf
# then press CPU_RESET on the board (Windows: --port COM5)
```

Compiling programs needs the RISC-V GCC: use Option B for that, or any
`riscv32-unknown-elf-gcc` with the `rv32imf_zicsr/ilp32f` multilib
(`make USE_DOCKER=0` in a program directory).

To put a program into the bitstream instead (no bootloader needed), copy its
`build/imem.hex` and `build/dmem.hex` over the ones in `build/vivado-<board>/` and
generate the bitstream again.

**Block design.** **Tools → Run Tcl Script…** → `fpga/ip/bd_demo.tcl`
packages `hornet_soc` as an IP (in `build/ip`), and creates
`build/vivado-bd/bd_demo/bd_demo.xpr` with a block design: HORNET, a clocking
wizard, a reset block and a Xilinx AXI GPIO on the LEDs, connected through
HORNET's `m_axi` port. Add your own AXI IP to the same port (addresses
`0x4000_0000`–`0x7FFF_FFFF`, **Address Editor**). See [fpga.md](fpga.md).

## Option B: Docker and Make

Requirements: Linux (or WSL2 on Windows) with Docker, `make`, `git`; Vivado
for the FPGA targets.

```bash
git clone --recurse-submodules https://github.com/GSTL-ITU/HORNET-RV32IMF.git
cd HORNET-RV32IMF
make docker-build        # once, about 30 minutes: Verilator, GCC, Spike, TestFloat, Yosys/SymbiYosys
make help                # all targets
```

Your user must be in the `docker` group (`sudo usermod -aG docker $USER`,
then log in again). On the host, `make` runs every tool in the image;
`make shell` opens a shell inside it.

### Run a program in simulation

```bash
make -C sw/tests/hello sim
# UART: Hello from HORNET (id 48524e54, 50000000 Hz)
# UART: 1.5 * 2.25 - 0.5 = 2875/1000 ok
# PASS cycles=18854 instret=9517
```

The SoC testbench decodes the UART, so `printf` output appears on the
terminal. A program ends the simulation by returning from `main`
(exit code 0 = PASS). New programs: [sw/README.md](../sw/README.md).

### Build a bitstream and program the board

```bash
make fpga-build FPGA_PROG=sw/examples/gpio                 # build/fpga/nexys4ddr/gpio/hornet_nexys4ddr.bit
make fpga-program FPGA_PROG=sw/examples/gpio               # over JTAG
make fpga-build FPGA_PROG=sw/examples/gpio BOOTLOADER=1    # the same with the UART bootloader
make fpga-project FPGA_PROG=sw/examples/gpio               # GUI project in build/fpga/nexys4ddr/project
make fpga-build BOARD=nexysvideo FPGA_PROG=sw/examples/gpio  # the same for the Nexys Video
```

`make fpga-build` prints the timing result
(`RESULT: WNS ... ns at 50.0 MHz`); the reports are in the output directory.

### Check that everything still works

```bash
make regress             # lint, FPU vectors, riscv-tests vs. Spike, random programs, formal (about an hour)
make sw-tests boot-test  # C programs on the SoC, the bootloader
```

[verification/README.md](verification/README.md) explains every check.

## Where to go next

| I want to … | Read |
|---|---|
| write a C program, use interrupts, the UART, the timer | [sw/README.md](../sw/README.md) |
| know the registers of a peripheral | [peripherals.md](peripherals.md) |
| connect my own hardware over AXI4-Lite | [fpga.md](fpga.md) |
| understand the pipeline or the FPU | [architecture.md](architecture.md) |
| change the RTL | [decisions/](decisions/), then `make regress` |
