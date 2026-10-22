# Batch build for the Nexys 4 DDR: synthesis, implementation, reports, bitstream.
#
#   vivado -mode batch -source build.tcl -tclargs <out dir> <imem.hex> <dmem.hex> [IMEM_SIZE DMEM_SIZE CLK_DIV BOOT_ADDR]
#
# The program images become the initial contents of the block RAMs.
set out       [file normalize [lindex $argv 0]]
set imem      [file normalize [lindex $argv 1]]
set dmem      [file normalize [lindex $argv 2]]
set imem_size [expr {[llength $argv] > 3 ? [lindex $argv 3] : 65536}]
set dmem_size [expr {[llength $argv] > 4 ? [lindex $argv 4] : 65536}]
set clk_div   [expr {[llength $argv] > 5 ? [lindex $argv 5] : 20}]
set boot_addr [expr {[llength $argv] > 6 ? [lindex $argv 6] : 0}]
set here      [file dirname [file normalize [info script]]]
set rtl       [file normalize $here/../../rtl]

file mkdir $out
cd $out
set_part xc7a100tcsg324-1
set_param general.maxThreads 4

read_verilog [glob $rtl/core/*.v] [glob $rtl/fpu/*.v] [glob $rtl/soc/*.v] $here/hornet_nexys4ddr.v
read_xdc $here/nexys4ddr.xdc
file copy -force $imem imem.hex
file copy -force $dmem dmem.hex

synth_design -top hornet_nexys4ddr -include_dirs [list $rtl/core $rtl/fpu] \
    -generic IMEM_SIZE=$imem_size -generic DMEM_SIZE=$dmem_size -generic CLK_DIV=$clk_div -generic BOOT_ADDR=$boot_addr \
    -generic IMEM_INIT=imem.hex -generic DMEM_INIT=dmem.hex
report_utilization -file utilization_synth.rpt
opt_design
place_design
phys_opt_design
route_design
report_utilization -file utilization.rpt
report_utilization -hierarchical -hierarchical_depth 3 -file utilization_hier.rpt
report_timing_summary -max_paths 20 -file timing.rpt
report_ram_utilization -file ram.rpt
write_bitstream -force hornet_nexys4ddr.bit

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set period [expr {10.0 * $clk_div / 10.0}]
puts "RESULT: WNS $wns ns at [expr {1000.0 / $period}] MHz (period $period ns)"
if {$wns < 0} {
    puts "RESULT: timing NOT met"
    exit 1
}
