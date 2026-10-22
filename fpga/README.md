# FPGA

Nexys 4 DDR top, constraints and Vivado scripts. The full guide is
[docs/fpga.md](../docs/fpga.md).

Quick start without any other tools: in Vivado, **Tools → Run Tcl Script →
`fpga/nexys4ddr/create_project.tcl`**, then **Generate Bitstream** and program
the board. LED0 blinks; the UART bootloader accepts programs from
`scripts/hornet_load.py` for one second after each reset.

With Make: `make fpga-build FPGA_PROG=sw/examples/gpio`, then
`make fpga-program FPGA_PROG=sw/examples/gpio`.

Block design with Xilinx AXI IP: `fpga/ip/bd_demo.tcl` (GUI) or `make fpga-bd`.
