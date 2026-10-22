# Block-design demo for the Nexys 4 DDR: the HORNET IP drives a Xilinx AXI GPIO
# (LEDs) through its m_axi port; the HORNET UART goes to the USB-UART bridge.
#
#   vivado -mode batch -source bd_demo.tcl -tclargs <out dir> <ip repo> <imem.hex> <dmem.hex>
#
# Without arguments (Vivado GUI: Tools > Run Tcl Script) it packages the IP if
# needed, uses the default images (bootloader + AXI GPIO counter) and creates
# build/vivado-bd/; in the GUI it stops after the block design so it can be
# opened and edited (Generate Bitstream builds it).
set here [file dirname [file normalize [info script]]]
set boot_addr 0
if {![info exists argv] || [llength $argv] == 0} {
    set argv [list $here/../../build/vivado-bd $here/../../build/ip $here/default/imem.hex $here/default/dmem.hex]
    set boot_addr 0xF000
}
set out  [file normalize [lindex $argv 0]]
set repo [file normalize [lindex $argv 1]]
set imem [file normalize [lindex $argv 2]]
set dmem [file normalize [lindex $argv 3]]
if {![file exists $repo/hornet_soc/component.xml]} {
    set saved_argv $argv
    set argv [list $repo]
    source $here/package_ip.tcl
    set argv $saved_argv
}

file mkdir $out
cd $out
file copy -force $imem $out/imem.hex
file copy -force $dmem $out/dmem.hex
create_project -force bd_demo $out/bd_demo -part xc7a100tcsg324-1
set_param general.maxThreads 4
set_property ip_repo_paths $repo [current_project]
update_ip_catalog

create_bd_design hornet_bd
create_bd_cell -type ip -vlnv gstl.itu:hornet:hornet_soc:1.0 hornet
set_property -dict [list CONFIG.IMEM_INIT $out/imem.hex CONFIG.DMEM_INIT $out/dmem.hex CONFIG.CLK_FREQ 50000000 \
    CONFIG.BOOT_ADDR $boot_addr] [get_bd_cells hornet]
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz clk
set_property -dict [list CONFIG.PRIM_IN_FREQ 100.000 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 50.000 CONFIG.USE_RESET false] [get_bd_cells clk]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio leds
set_property -dict [list CONFIG.C_GPIO_WIDTH 16 CONFIG.C_ALL_OUTPUTS 1] [get_bd_cells leds]

create_bd_port -dir I -type clk -freq_hz 100000000 CLK100MHZ
create_bd_port -dir I -type rst CPU_RESETN
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports CPU_RESETN]
create_bd_port -dir I UART_TXD_IN
create_bd_port -dir O UART_RXD_OUT
create_bd_port -dir O -from 15 -to 0 LED

connect_bd_net [get_bd_ports CLK100MHZ] [get_bd_pins clk/clk_in1]
connect_bd_net [get_bd_pins clk/clk_out1] [get_bd_pins hornet/clk_i] [get_bd_pins leds/s_axi_aclk] [get_bd_pins rst/slowest_sync_clk]
connect_bd_net [get_bd_pins clk/locked] [get_bd_pins rst/dcm_locked]
connect_bd_net [get_bd_ports CPU_RESETN] [get_bd_pins rst/ext_reset_in]
connect_bd_net [get_bd_pins rst/peripheral_aresetn] [get_bd_pins hornet/rst_ni] [get_bd_pins leds/s_axi_aresetn]
connect_bd_net [get_bd_ports UART_TXD_IN] [get_bd_pins hornet/uart_rx_i]
connect_bd_net [get_bd_ports UART_RXD_OUT] [get_bd_pins hornet/uart_tx_o]
connect_bd_net [get_bd_ports LED] [get_bd_pins leds/gpio_io_o]
connect_bd_intf_net [get_bd_intf_pins hornet/m_axi] [get_bd_intf_pins leds/S_AXI]
assign_bd_address -target_address_space /hornet/m_axi [get_bd_addr_segs leds/S_AXI/Reg] -offset 0x40000000 -range 64K
validate_bd_design
save_bd_design

make_wrapper -files [get_files hornet_bd.bd] -top -import
set_property top hornet_bd_wrapper [current_fileset]
add_files -fileset constrs_1 $here/bd_demo.xdc
if {$rdi::mode eq "gui"} {
    puts "RESULT: block design created in $out/bd_demo; run Generate Bitstream"
    return
}
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
open_run impl_1
report_timing_summary -file $out/timing.rpt
report_utilization -file $out/utilization.rpt
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "RESULT: block design bitstream [glob -nocomplain $out/bd_demo/bd_demo.runs/impl_1/*.bit], WNS $wns ns"
