# Loads a board definition: fpga/<board>/board.tcl sets
#   board_name      shown in the reports
#   board_part      FPGA part
#   board_hw        device name on the JTAG chain (part without package and speed grade)
#   board_xdc       constraints (in the board directory)
#   board_generics  generics of hornet_board for this board (LED and switch counts)
# The board comes from the variable `board` (set by the wrappers in the board
# directories) or from the first script argument.
set fpga_dir [file normalize [file dirname [info script]]/..]
if {![info exists board]} {
    if {![info exists argv] || [llength $argv] == 0} {
        error "no board: source fpga/<board>/[file tail $script_name] or pass the board as the first argument"
    }
    set board [lindex $argv 0]
    set argv [lrange $argv 1 end]
}
set board_dir $fpga_dir/$board
if {![file exists $board_dir/board.tcl]} {
    set boards {}
    foreach d [glob -directory $fpga_dir -type d *] {
        if {[file exists $d/board.tcl]} { lappend boards [file tail $d] }
    }
    error "unknown board '$board' (boards: $boards)"
}
source $board_dir/board.tcl
set rtl [file normalize $fpga_dir/../rtl]

# Program arguments: <dir> <imem.hex> <dmem.hex> [IMEM_SIZE DMEM_SIZE CLK_DIV BOOT_ADDR RV_M RV_F];
# without them the default images (bootloader + LED blink, RV32IMF) and <default dir>.
# RV_M/RV_F select the ISA (rv32i: 0 0, rv32im: 1 0, rv32imf: 1 1); the
# program images must be built for the same ISA (make ... ISA=rv32im).
proc board_args {default_dir} {
    global argv fpga_dir out imem dmem imem_size dmem_size clk_div boot_addr rv_m rv_f
    if {![info exists argv] || [llength $argv] == 0} {
        set argv [list $default_dir $fpga_dir/default/imem.hex $fpga_dir/default/dmem.hex 65536 65536 20 0xF000 1 1]
    }
    set out       [file normalize [lindex $argv 0]]
    set imem      [file normalize [lindex $argv 1]]
    set dmem      [file normalize [lindex $argv 2]]
    set imem_size [expr {[llength $argv] > 3 ? [lindex $argv 3] : 65536}]
    set dmem_size [expr {[llength $argv] > 4 ? [lindex $argv 4] : 65536}]
    set clk_div   [expr {[llength $argv] > 5 ? [lindex $argv 5] : 20}]
    set boot_addr [expr {[llength $argv] > 6 ? [lindex $argv 6] : 0}]
    set rv_m      [expr {[llength $argv] > 7 ? [lindex $argv 7] : 1}]
    set rv_f      [expr {[llength $argv] > 8 ? [lindex $argv 8] : 1}]
}

# ISA name of the configuration, e.g. RV32IMF
proc board_isa {} {
    global rv_m rv_f
    return "RV32I[expr {$rv_m ? "M" : ""}][expr {$rv_f ? "F" : ""}]"
}

proc board_generic_list {} {
    global imem_size dmem_size clk_div boot_addr rv_m rv_f board_generics
    return [concat [list IMEM_SIZE=$imem_size DMEM_SIZE=$dmem_size CLK_DIV=$clk_div BOOT_ADDR=$boot_addr \
                         RV_M=$rv_m RV_F=$rv_f IMEM_INIT=imem.hex DMEM_INIT=dmem.hex] $board_generics]
}
