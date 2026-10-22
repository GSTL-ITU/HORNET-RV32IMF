# HORNET on the FPGA

Board: Digilent **Nexys 4 DDR** (Artix-7 `xc7a100tcsg324-1`). Vivado 2025.2.
Everything is in `fpga/`:

| File | |
|---|---|
| `nexys4ddr/hornet_nexys4ddr.v` | board top: MMCM (100 MHz → 1000 MHz / `CLK_DIV`), reset, LEDs, switches, buttons, Pmod JA, `hornet_soc` |
| `nexys4ddr/nexys4ddr.xdc` | pins used by the top (taken from Digilent's master file) |
| `nexys4ddr/Nexys-4-DDR-Master.xdc` | Digilent's master constraints, unchanged, for reference |
| `nexys4ddr/build.tcl` | batch: synthesis, implementation, reports, bitstream |
| `nexys4ddr/create_project.tcl` | GUI project |
| `nexys4ddr/program.tcl` | JTAG programming |
| `nexys4ddr/default/` | default block-RAM images: bootloader + LED blink |
| `ip/package_ip.tcl` | `hornet_soc` as a Vivado IP (`m_axi` AXI4-Lite master) |
| `ip/bd_demo.tcl`, `ip/bd_demo.xdc`, `ip/default/` | block-design demo with a Xilinx AXI GPIO |

## Four ways to a bitstream

| Way | Command | Result |
|---|---|---|
| Vivado GUI, no tools | Tools → Run Tcl Script → `fpga/nexys4ddr/create_project.tcl` | `build/vivado/hornet.xpr` with the default images; Generate Bitstream |
| Make, batch | `make fpga-build FPGA_PROG=sw/examples/gpio` | `build/fpga/gpio/hornet_nexys4ddr.bit` and reports |
| Make, GUI project for a program | `make fpga-project FPGA_PROG=sw/examples/gpio` | `build/fpga/project/hornet.xpr` |
| Vivado batch without Make | `vivado -mode batch -source fpga/nexys4ddr/build.tcl` | `build/vivado-batch/` with the default images |

`make fpga-program FPGA_PROG=…` (or `program.tcl`, or the Hardware Manager)
loads the bitstream over JTAG.

Options of `make fpga-build`:

| Variable | Default | |
|---|---|---|
| `FPGA_PROG` | `sw/examples/gpio` | program directory; its `build/imem.hex`, `dmem.hex` and memory sizes are used |
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

Vivado 2025.2, `xc7a100tcsg324-1`, default strategies:

| Build | Clock | Worst setup slack | LUTs | FFs | DSP | BRAM36 |
|---|---|---|---|---|---|---|
| board top, 64 KB + 64 KB (`sw/examples/gpio`) | 50 MHz | +0.85 ns | 6.6 k | 2.8 k | 6 | 32 |
| block-design demo (HORNET + AXI GPIO) | 50 MHz | +0.94 ns | | | | |
| board top, 320 KB + 64 KB + bootloader (MLP example) | 41.7 MHz | see below | 7.2 k | | 6 | 112 |

At 50 MHz the MLP build misses timing by 0.53 ns: 112 of the 135 block RAMs
spread over the device and the IMEM output multiplexers add delay, so that
example uses `CLK_DIV = 24`.

The critical path of the default build is a load result forwarded into a
branch comparison whose target is sent to the instruction memory in the same
cycle ([architecture.md](architecture.md#clock-and-resources)).
