#!/bin/sh
# Runs a program on the board without touching it: the UART loader starts
# first and calls the bootloader, then programming the bitstream over JTAG
# resets the board into the bootloader, which loads and starts the program.
# The UART output goes to <log> until a line contains <until>.
#
#   scripts/fpga_run.sh <board> <bitstream> <serial port> <prog.elf> <log> [until] [timeout s]
#
# The bitstream must contain the bootloader (make fpga-build BOOTLOADER=1) and
# the program must be built for the same IMEM_SIZE and DMEM_SIZE.
set -e
board=$1 bit=$2 port=$3 elf=$4 log=$5 until=${6:-"result "} limit=${7:-3600}
root=$(cd "$(dirname "$0")/.." && pwd)
vivado=${VIVADO:-vivado}
image=${IMAGE:-hornet-dev:latest}
elf=$(realpath "$elf")
log=$(realpath -m "$log")
mkdir -p "$(dirname "$log")"
edir=$(dirname "$elf")
ldir=$(dirname "$log")

docker run --rm --device "$port" -u "$(id -u):$(id -g)" --group-add "$(stat -c %g "$port")" \
    -v "$root:/work" -v "$edir:$edir" -v "$ldir:$ldir" -w /work "$image" \
    timeout "$limit" python3 scripts/hornet_load.py --port "$port" --wait 180 --term --until "$until" \
    --log "$log" "$elf" > "$log.console" 2>&1 &
loader=$!
sleep 3
"$vivado" -mode batch -nojournal -nolog -source "$root/fpga/common/program.tcl" -tclargs "$board" "$bit" \
    > "$log.jtag" 2>&1
if wait $loader; then
    echo "done: $log"
else
    echo "loader failed, see $log.console" >&2
    exit 1
fi
