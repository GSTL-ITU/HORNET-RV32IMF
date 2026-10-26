# Program this board over JTAG: vivado -mode batch -source program.tcl -tclargs <bitstream>
set board nexysvideo
source [file dirname [file normalize [info script]]]/../common/program.tcl
