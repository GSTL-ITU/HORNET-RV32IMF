# Vivado GUI project for the Nexys 4 DDR, with the program images in the block RAMs.
#
#   vivado -mode batch -source create_project.tcl -tclargs <dir> <imem.hex> <dmem.hex> [IMEM_SIZE DMEM_SIZE CLK_DIV BOOT_ADDR]
#
# Without arguments (Vivado GUI: Tools > Run Tcl Script) it creates
# build/vivado/hornet.xpr with the default images (bootloader + LED blink).
# To change the program, rebuild the images and replace imem.hex/dmem.hex in
# the project directory, then Generate Bitstream.
set here      [file dirname [file normalize [info script]]]
set rtl       [file normalize $here/../../rtl]
if {![info exists argv] || [llength $argv] == 0} {
    set argv [list $here/../../build/vivado $here/default/imem.hex $here/default/dmem.hex 65536 65536 20 0xF000]
}
set dir       [file normalize [lindex $argv 0]]
set imem      [file normalize [lindex $argv 1]]
set dmem      [file normalize [lindex $argv 2]]
set imem_size [expr {[llength $argv] > 3 ? [lindex $argv 3] : 65536}]
set dmem_size [expr {[llength $argv] > 4 ? [lindex $argv 4] : 65536}]
set clk_div   [expr {[llength $argv] > 5 ? [lindex $argv 5] : 20}]
set boot_addr [expr {[llength $argv] > 6 ? [lindex $argv 6] : 0}]

create_project hornet $dir -part xc7a100tcsg324-1 -force
add_files [glob $rtl/core/*.v] [glob $rtl/fpu/*.v] [glob $rtl/soc/*.v] $here/hornet_nexys4ddr.v
add_files [glob $rtl/core/*.vh]
set_property is_global_include true [get_files hornet_defs.vh]
file copy -force $imem $dir/imem.hex
file copy -force $dmem $dir/dmem.hex
add_files -norecurse $dir/imem.hex $dir/dmem.hex
set_property file_type {Memory Initialization Files} [get_files *.hex]
add_files -fileset constrs_1 $here/nexys4ddr.xdc
set_property top hornet_nexys4ddr [current_fileset]
set_property generic "IMEM_SIZE=$imem_size DMEM_SIZE=$dmem_size CLK_DIV=$clk_div BOOT_ADDR=$boot_addr IMEM_INIT=imem.hex DMEM_INIT=dmem.hex" [current_fileset]
set_property include_dirs [list $rtl/core $rtl/fpu] [current_fileset]
update_compile_order -fileset sources_1
puts "RESULT: project $dir/hornet.xpr"
