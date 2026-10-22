#!/bin/sh
# riscv-formal checks on the core's RVFI port.
#
#   scripts/run_formal.sh <build dir> <jobs> [check ...]
#
# Builds <build dir>/formal with riscv-formal's expected layout (checks/ and
# insns/ linked from the submodule, the core in cores/hornet/), generates the
# checks from verif/formal/checks.cfg and runs them. FORMAL_TIMEOUT (seconds)
# limits each check; a check that hits it is reported as TIMEOUT.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$1"
dir=$(cd "$1" && pwd)/formal
jobs=$2
shift 2
core=$dir/cores/hornet

rm -rf "$dir"
mkdir -p "$core"
ln -s "$root/verif/riscv-formal/checks" "$dir/checks"
ln -s "$root/verif/riscv-formal/insns" "$dir/insns"
cp "$root/verif/formal/wrapper.sv" "$core/"
sed "s|%RTL%|$root/rtl|g" "$root/verif/formal/checks.cfg" > "$core/checks.cfg"

cd "$core"
python3 ../../checks/genchecks.py > genchecks.log
if [ "${FORMAL_TIMEOUT:-0}" -gt 0 ]; then
    sed -i "/^\[options\]/a timeout $FORMAL_TIMEOUT" checks/*.sby
fi
make -k -s -C checks -j"$jobs" "$@" > make.log 2>&1 || true
python3 "$root/scripts/formal_summary.py" checks "$@"
