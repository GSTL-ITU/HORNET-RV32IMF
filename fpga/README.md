# FPGA

Board top (`common/`), constraints and Vivado scripts for the Nexys 4 DDR
(`nexys4ddr/`) and the Nexys Video (`nexysvideo/`). The full guide, also for
adding a board, is [docs/fpga.md](../docs/fpga.md).

Quick start without any other tools: in Vivado, **Tools → Run Tcl Script →
`fpga/<board>/create_project.tcl`**, then **Generate Bitstream** and program
the board. LED0 blinks; the UART bootloader accepts programs from
`scripts/hornet_load.py` for one second after each reset.

With Make: `make fpga-build BOARD=<board> FPGA_PROG=sw/examples/gpio`, then
`make fpga-program BOARD=<board> FPGA_PROG=sw/examples/gpio` (`BOARD` is
`nexys4ddr` by default).

Block design with Xilinx AXI IP: `fpga/ip/bd_demo.tcl` (GUI) or `make fpga-bd`.
