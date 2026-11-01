# Default program images

`imem.hex` and `dmem.hex` are the block-RAM contents the Vivado scripts use
when they are started without arguments (for example from the Vivado GUI):
the UART bootloader (`sw/bootloader`, top 4 KB of IMEM, reset vector
`0xF000`) and the LED blink example (`sw/examples/gpio`) at address 0.

After programming, LED0 blinks. Within one second after pressing CPU_RESET,
`scripts/hornet_load.py` can load any other program over the USB-UART.
The same images serve every board (`fpga/<board>/create_project.tcl`, `build.tcl`).

Regenerate them with `make fpga-default` after changing the bootloader or the
example (64 KB IMEM, 64 KB DMEM).
