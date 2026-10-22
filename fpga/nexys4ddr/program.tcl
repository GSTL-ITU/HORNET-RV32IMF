# Program the Nexys 4 DDR over JTAG: vivado -mode batch -source program.tcl -tclargs <bitstream>
open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7a100t*] 0]
current_hw_device $dev
set_property PROGRAM.FILE [lindex $argv 0] $dev
program_hw_devices $dev
close_hw_manager
