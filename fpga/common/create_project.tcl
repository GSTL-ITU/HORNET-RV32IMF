# Vivado GUI project for a board, with the program images in the block RAMs.
#
#   vivado -mode batch -source fpga/common/create_project.tcl -tclargs <board> <dir> <imem.hex> <dmem.hex> [IMEM_SIZE DMEM_SIZE CLK_DIV BOOT_ADDR]
#   Vivado GUI: Tools > Run Tcl Script > fpga/<board>/create_project.tcl
#
# Without program arguments it creates build/vivado-<board>/hornet.xpr with the
# default images (bootloader + LED blink). To change the program, rebuild the
# images and replace imem.hex/dmem.hex in the project directory, then Generate Bitstream.
set script_name create_project.tcl
source [file dirname [file normalize [info script]]]/board.tcl
board_args $fpga_dir/../build/vivado-$board
set dir $out

create_project hornet $dir -part $board_part -force
add_files [glob $rtl/core/*.v] [glob $rtl/fpu/*.v] [glob $rtl/soc/*.v] $fpga_dir/common/hornet_board.v
add_files [glob $rtl/core/*.vh]
set_property is_global_include true [get_files hornet_defs.vh]
file copy -force $imem $dir/imem.hex
file copy -force $dmem $dir/dmem.hex
add_files -norecurse $dir/imem.hex $dir/dmem.hex
set_property file_type {Memory Initialization Files} [get_files *.hex]
add_files -fileset constrs_1 $board_dir/$board_xdc
set_property top hornet_board [current_fileset]
set_property generic [join [board_generic_list] " "] [current_fileset]
set_property include_dirs [list $rtl/core $rtl/fpu] [current_fileset]
update_compile_order -fileset sources_1
puts "RESULT: $board_name project $dir/hornet.xpr"
