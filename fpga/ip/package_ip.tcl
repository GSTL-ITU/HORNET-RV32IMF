# Packages hornet_soc as a Vivado IP for block designs.
#
#   vivado -mode batch -source package_ip.tcl -tclargs <out dir>
#
# The IP has clk_i/rst_ni, the UART and GPIO pins, the interrupt inputs and an
# AXI4-Lite master interface m_axi with a 4 GB address space; the HORNET
# peripherals occupy 0x2000_0000-0x2003_FFFF, so assign external slaves in
# 0x4000_0000-0x7FFF_FFFF. IMEM_INIT/DMEM_INIT take absolute paths of the
# program images (sw/<program>/build/imem.hex and dmem.hex). RV_M and RV_F
# select the ISA; the program must be built for it (make ISA=...).
if {![info exists argv] || [llength $argv] == 0} { set argv [list [file normalize [file dirname [info script]]/../../build/ip]] }
set out  [file normalize [lindex $argv 0]]
set here [file dirname [file normalize [info script]]]
set rtl  [file normalize $here/../../rtl]

file mkdir $out
cd $out
create_project -force pkg $out/pkg -part xc7a100tcsg324-1
set srcs [concat [glob $rtl/core/*.v] [glob $rtl/fpu/*.v] [glob $rtl/soc/*.v] [glob $rtl/core/*.vh]]
add_files $srcs
set_property is_global_include true [get_files hornet_defs.vh]
set_property top hornet_soc [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $out/hornet_soc -vendor gstl.itu -library hornet -name hornet_soc \
    -version 1.0 -taxonomy /Embedded_Processing/Processor -import_files -force
set core [ipx::current_core]
set_property display_name "HORNET RV32I(M)(F) SoC" $core
set_property description "HORNET RV32I core with optional M and F extensions, instruction/data block RAMs, timer, UART, GPIO and an AXI4-Lite master port" $core

# ISA: the M and F extensions are IP parameters (0 or 1) on the Customize IP page
foreach {param name} {RV_M "M extension (multiply, divide)" RV_F "F extension (single-precision FPU)"} {
    set up [ipx::get_user_parameters $param -of_objects $core]
    set_property display_name $name $up
    set_property value_validation_type list $up
    set_property value_validation_list {0 1} $up
}
set_property supported_families {artix7 Production kintex7 Production spartan7 Production} $core

ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 $core
ipx::infer_bus_interface clk_i xilinx.com:signal:clock_rtl:1.0 $core
ipx::infer_bus_interface rst_ni xilinx.com:signal:reset_rtl:1.0 $core
set clk_if clk_i
set rst_if rst_ni
ipx::associate_bus_interfaces -busif m_axi -clock $clk_if $core
ipx::associate_bus_interfaces -clock $clk_if -reset $rst_if $core
set rst_bif [ipx::get_bus_interfaces $rst_if -of_objects $core]
if {[llength [ipx::get_bus_parameters POLARITY -of_objects $rst_bif]] == 0} {
    ipx::add_bus_parameter POLARITY $rst_bif
}
set_property value ACTIVE_LOW [ipx::get_bus_parameters POLARITY -of_objects $rst_bif]

if {[llength [ipx::get_address_spaces m_axi -of_objects $core]] == 0} {
    ipx::add_address_space m_axi $core
    set_property master_address_space_ref m_axi [ipx::get_bus_interfaces m_axi -of_objects $core]
}
set_property range 4G [ipx::get_address_spaces m_axi -of_objects $core]
set_property width 32 [ipx::get_address_spaces m_axi -of_objects $core]

ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
close_project
puts "RESULT: IP packaged in $out/hornet_soc ([ipx::get_bus_interfaces -of_objects [ipx::open_core $out/hornet_soc/component.xml]])"
