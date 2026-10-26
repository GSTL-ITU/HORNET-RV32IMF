# Program a board over JTAG:
#   vivado -mode batch -source fpga/common/program.tcl -tclargs <board> <bitstream>
#   vivado -mode batch -source fpga/<board>/program.tcl -tclargs <bitstream>
set script_name program.tcl
source [file dirname [file normalize [info script]]]/board.tcl
set bit [lindex $argv 0]
open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices $board_hw*] 0]
if {$dev eq ""} {
    error "no $board_hw on the JTAG chain (devices: [get_hw_devices])"
}
current_hw_device $dev
set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
close_hw_manager
