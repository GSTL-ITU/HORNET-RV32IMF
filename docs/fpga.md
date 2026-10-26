# HORNET on the FPGA

Boards: Digilent **Nexys 4 DDR** (Artix-7 `xc7a100tcsg324-1`) and **Nexys
Video** (Artix-7 `xc7a200tsbg484-1`). Vivado 2025.2. Everything is in `fpga/`:

| File | |
|---|---|
| `common/hornet_board.v` | board top for every board: MMCM (100 MHz → 1000 MHz / `CLK_DIV`), reset, LEDs, switches, buttons, Pmod JA, `hornet_soc`; `N_LED`, `N_SW` set the widths |
| `common/build.tcl` | batch: synthesis, implementation, reports, bitstream |
| `common/create_project.tcl` | GUI project |
| `common/program.tcl` | JTAG programming |
| `common/board.tcl` | loads a board definition |
| `<board>/board.tcl` | the board: name, part, JTAG device, constraints, LED and switch counts |
| `<board>/<board>.xdc` | pins used by the top (taken from Digilent's master file, renamed to the top's ports) |
| `<board>/*-Master.xdc` | Digilent's master constraints, unchanged, for reference |
| `<board>/build.tcl`, `create_project.tcl`, `program.tcl` | the common scripts for this board (Vivado GUI: Tools → Run Tcl Script) |
| `default/` | default block-RAM images: bootloader + LED blink |
| `ip/package_ip.tcl` | `hornet_soc` as a Vivado IP (`m_axi` AXI4-Lite master) |
| `ip/bd_demo.tcl`, `ip/bd_demo.xdc`, `ip/default/` | block-design demo with a Xilinx AXI GPIO (Nexys 4 DDR) |

| Board | `BOARD` | LEDs | Switches | UART | Notes |
|---|---|---|---|---|---|
| Nexys 4 DDR | `nexys4ddr` (default) | 16 | 16 | USB-UART on the PROG/UART port | |
| Nexys Video | `nexysvideo` | 8 | 8 | separate UART micro-USB port (FT232R) | switches and buttons are on the VADJ banks: the constraints use LVCMOS12, the default setting of jumper JP6 (1.2 V) |

### Another board

Copy `fpga/nexysvideo/` to `fpga/<name>/`, set the part, the JTAG device
name and the LED/switch counts in `board.tcl`, map the ports of
`common/hornet_board.v` (`CLK100MHZ`, `CPU_RESETN`, `UART_TXD_IN`,
`UART_RXD_OUT`, `SW[]`, `BTN*`, `LED[]`, `JA[]`) to the board's pins in the
`.xdc`, and build with `BOARD=<name>`. The top expects a 100 MHz oscillator
and an active-low reset button; for others change the MMCM settings or
invert the reset in `hornet_board.v`.

## Four ways to a bitstream

| Way | Command | Result |
|---|---|---|
| Vivado GUI, no tools | Tools → Run Tcl Script → `fpga/<board>/create_project.tcl` | `build/vivado-<board>/hornet.xpr` with the default images; Generate Bitstream |
| Make, batch | `make fpga-build BOARD=<board> FPGA_PROG=sw/examples/gpio` | `build/fpga/<board>/gpio/hornet_<board>.bit` and reports |
| Make, GUI project for a program | `make fpga-project BOARD=<board> FPGA_PROG=sw/examples/gpio` | `build/fpga/<board>/project/hornet.xpr` |
| Vivado batch without Make | `vivado -mode batch -source fpga/<board>/build.tcl` | `build/vivado-batch-<board>/` with the default images |

`make fpga-program BOARD=<board> FPGA_PROG=…` (or `program.tcl`, or the
Hardware Manager) loads the bitstream over JTAG.

Options of `make fpga-build`:

| Variable | Default | |
|---|---|---|
| `BOARD` | `nexys4ddr` | a directory `fpga/<BOARD>/` with `board.tcl` |
| `FPGA_PROG` | `sw/examples/gpio` | program directory; its `build/imem.hex`, `dmem.hex` and memory sizes are used (`IMEM_SIZE=… DMEM_SIZE=…` on the command line are passed to its build) |
| `BOOTLOADER` | 0 | 1: add the UART bootloader at the top of IMEM and start there |
| `CLK_DIV` | the program's `CLK_DIV`, normally 20 | core clock = 1000 MHz / `CLK_DIV` (20 → 50 MHz, 24 → 41.7 MHz) |

The program images are the initial contents of the block RAMs, so changing
the program means a new bitstream, or the bootloader.

## Bootloader

`sw/bootloader` occupies the top 4 KB of IMEM and 1 KB at the top of DMEM.
After reset it listens on the UART for one second; without a host it starts
the program at address 0 (the one in the bitstream). With
`scripts/hornet_load.py` it receives an ELF in CRC-checked blocks and starts it:

```bash
make fpga-build FPGA_PROG=sw/examples/gpio BOOTLOADER=1
make fpga-program FPGA_PROG=sw/examples/gpio
python3 scripts/hornet_load.py --port /dev/ttyUSB1 --term sw/tests/hello/build/hello.elf   # press CPU_RESET
```

Without anyone at the board, `make fpga-run` (`scripts/fpga_run.sh`) starts
the loader in the Docker image, programs the bitstream over JTAG (which
resets the board into the bootloader), and logs the UART output until a line
contains `result ` (or the text given to the script):

```bash
make fpga-build BOARD=nexysvideo FPGA_PROG=sw/examples/gpio BOOTLOADER=1 IMEM_SIZE=0x40000 DMEM_SIZE=0x40000
make fpga-run BOARD=nexysvideo FPGA_BIT=build/fpga/nexysvideo/gpio/hornet_nexysvideo.bit \
    ELF=<program built with IMEM_SIZE=0x40000 DMEM_SIZE=0x40000> PORT=/dev/ttyUSB0 LOG=build/run.log
```

Programs loaded this way must fit below the bootloader (IMEM size − 4 KB) and
below the top 1 KB of DMEM; `make fpga-build BOOTLOADER=1` reports an
overlap. `make boot-test` checks the whole path in simulation.

## Block designs and Vivado IP

```bash
make fpga-ip     # build/ip/hornet_soc: IP "HORNET RV32IMF SoC" (vendor gstl.itu)
make fpga-bd     # block design with the IP and a Xilinx AXI GPIO, built to a bitstream
```

or, in the GUI: Tools → Run Tcl Script → `fpga/ip/bd_demo.tcl` (it packages
the IP when needed and stops after creating the block design).

The demo block design contains:

```
CLK100MHZ -> clk_wiz (50 MHz) -> hornet_soc.clk_i, axi_gpio.s_axi_aclk
CPU_RESETN -> proc_sys_reset -> hornet_soc.rst_ni, axi_gpio.s_axi_aresetn
hornet_soc.m_axi (AXI4-Lite master) -> axi_gpio.S_AXI   @ 0x4000_0000
hornet_soc.uart_*  -> USB-UART           axi_gpio.gpio_io_o -> LED[15:0]
```

To use the IP in your own design: Settings → IP → Repository → add
`build/ip`; add "HORNET RV32IMF SoC"; set `IMEM_INIT`/`DMEM_INIT` to the
absolute paths of the program images, `CLK_FREQ` to the clock you connect and
the memory sizes if needed; connect `m_axi` to your AXI4-Lite slaves (through
an AXI SmartConnect for more than one) and assign them addresses in
`0x4000_0000`–`0x7FFF_FFFF`.

## Results

Vivado 2025.2, default strategies:

| Board | Build | Clock | Worst setup slack | LUTs | FFs | DSP | BRAM36 |
|---|---|---|---|---|---|---|---|
| Nexys 4 DDR | board top, 64 KB + 64 KB (`sw/examples/gpio`) | 50 MHz | +0.85 ns | 6.6 k | 2.8 k | 6 | 32 |
| Nexys 4 DDR | board top, default images (bootloader + LED blink) | 50 MHz | +0.98 ns | | | 6 | 32 |
| Nexys 4 DDR | block-design demo (HORNET + AXI GPIO) | 50 MHz | +0.94 ns | | | 6 | 32 |
| Nexys 4 DDR | board top, 320 KB + 64 KB + bootloader (MLP example) | 41.7 MHz | +0.75 ns | 7.6 k | 3.3 k | 6 | 112 |
| Nexys Video | board top, 256 KB + 256 KB + bootloader (PQC benchmarks) | 50 MHz | +0.46 ns | 7.0 k | 2.9 k | 6 | 128 |

At 50 MHz the MLP build misses timing by 0.53 ns: 112 of the 135 block RAMs
spread over the device and the IMEM output multiplexers add delay, so that
example uses `CLK_DIV = 24`.

The critical path of the default build is a load result forwarded into a
branch comparison whose target is sent to the instruction memory in the same
cycle ([architecture.md](architecture.md#clock-and-resources)).
