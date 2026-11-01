# Quick start

There are two ways to start. **Path A** needs only Vivado and a board, and
puts a running HORNET on the FPGA in about ten minutes. **Path B** adds the
Docker image with the compiler, the simulators and the verification tools,
and drives everything with `make`. Both start from a clone of the
repository:

```bash
git clone --recurse-submodules https://github.com/GSTL-ITU/HORNET-RV32IMF.git
cd HORNET-RV32IMF
```

(`--recurse-submodules` fetches riscv-tests, riscv-formal and RISCV-DV;
Path A does not need them, and `make` fetches them on first use.)

## Path A: Vivado only

**You need:** Vivado 2025.2 (other recent versions should work), a Digilent
Nexys 4 DDR (Artix-7 100T) or Nexys Video (Artix-7 200T), and its USB cable(s).
On the Nexys Video the UART has its own micro-USB port.

1. Start Vivado and choose **Tools → Run Tcl Script…**. Select
   `fpga/nexys4ddr/create_project.tcl` (Nexys Video:
   `fpga/nexysvideo/create_project.tcl`). The script creates
   `build/vivado-<board>/hornet.xpr` with all RTL, the constraints and the
   default memory images from `fpga/default/` (the UART bootloader and an
   LED-blink program), and opens it.
2. Click **Generate Bitstream** (about five minutes).
3. **Open Hardware Manager → Open Target → Auto Connect → Program Device.**
   LED0 starts blinking: HORNET is running.

### Load your own program without a new bitstream

The default bitstream contains the UART bootloader. After each press of
**CPU_RESET** it listens on the USB-UART for one second; if a host answers,
it receives a program and starts it, otherwise it starts the LED blink.

```bash
pip install pyserial pyelftools
python3 scripts/hornet_load.py --port /dev/ttyUSB1 --term \
    sw/tests/hello/build/hello.elf
# then press CPU_RESET on the board        (Windows: --port COM5)
```

`--term` keeps the connection open and prints what the program sends
(`printf` goes to the UART at 115200 baud). Building a program needs the
RISC-V compiler, which comes with Path B, or any `riscv32-unknown-elf-gcc`
with the `rv32imf_zicsr/ilp32f` multilib (`make USE_DOCKER=0` in the program
directory).

### Use HORNET in a block design

**Tools → Run Tcl Script…** → `fpga/ip/bd_demo.tcl` packages HORNET as a
Vivado IP (into `build/ip`) and creates a block design with a clocking
wizard, a reset block and a Xilinx AXI GPIO driving the LEDs through HORNET's
`m_axi` port. Further AXI4-Lite IP is added to the same port at addresses
`0x4000_0000`–`0x7FFF_FFFF` with the Address Editor. See [FPGA](fpga.md).

## Path B: Docker and Make

**You need:** Linux with Docker Engine, `make` and `git` (on Windows: WSL2
with Docker Desktop's WSL integration, or Docker Engine inside WSL2); Vivado
on the host for the FPGA targets.

```bash
make docker-build        # once, 30-60 minutes: builds the hornet-dev image
make help                # every target, with its options
```

Your user must be allowed to run Docker (`sudo usermod -aG docker $USER`,
then log in again). On the host every `make` target runs its tool inside the
image; `make shell` opens a shell in the image with the repository mounted.
[Repository and environment](repository.md) explains how this works.

**VS Code:** with the *Dev Containers* extension, **Reopen in Container**
uses `.devcontainer/devcontainer.json` to open the repository inside the
same image; `make` then runs the tools directly.

### Run a C program in simulation

```bash
make -C sw/tests/hello sim
```

```text
UART: Hello from HORNET (id 48524e54, 50000000 Hz)
UART: 1.5 * 2.25 - 0.5 = 2875/1000 ok
PASS cycles=18854 instret=9517
```

The SoC testbench decodes the UART, so `printf` output appears in the
terminal. A program ends the simulation by returning from `main`; return
value 0 means PASS.

### Write your own program

```bash
mkdir -p sw/examples/blink && cd sw/examples/blink
cat > main.c <<'EOF'
#include <stdio.h>
#include "gpio.h"
#include "timer.h"

int main(void)
{
    printf("blink\n");
    gpio_set_dir(0xffff);           /* LEDs are outputs */
    for (;;) {
        gpio_toggle_pin(0);
        delay_ms(250);
    }
}
EOF
printf 'include ../../common.mk\n' > Makefile
make                                 # build/blink.elf, imem/dmem images
```

[Software](software.md) describes the build rules, the drivers and
interrupts.

### Put the program on the board

```bash
# bitstream with the program in the BRAMs
make fpga-build FPGA_PROG=sw/examples/blink
# program the board over JTAG
make fpga-program FPGA_PROG=sw/examples/blink
# the same for the Nexys Video
make fpga-build BOARD=nexysvideo FPGA_PROG=sw/examples/blink
```

### Choose the ISA configuration

Every target takes `ISA=rv32i`, `rv32im` or `rv32imf` (default):

```bash
make -C sw/tests/hello sim ISA=rv32im
make fpga-build FPGA_PROG=sw/examples/blink ISA=rv32i
```

The compiler then generates code for that ISA (floating point in software
without F, multiply and divide in software without M).

### Check that everything works

```bash
# lint, FPU vectors, riscv-tests vs. Spike, random programs, SoC tests, formal
make regress
# the simulation checks for all three ISA configurations
make regress-isas
# RISCV-DV programs vs. Spike
make riscv-dv
```

[Verification](verification.md) explains every check and lists the current
results.

### Build the manuals

```bash
make docs        # build/docs/hornet-manual.pdf, build/docs/hornet-student-manual.pdf
make docs-html   # build/docs/html/index.html
```
