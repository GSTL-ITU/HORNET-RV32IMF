#!/bin/sh
# riscv-formal checks on the core's RVFI port.
#
#   scripts/run_formal.sh <build dir> <jobs> [check ...]
#
# HORNET_ISA (rv32i, rv32im, rv32imf; default rv32imf) selects the core
# configuration; riscv-formal checks its integer part (rv32i or rv32im).
#
# Builds <build dir>/formal with riscv-formal's expected layout (checks/ and
# insns/ linked from the submodule, the core in cores/hornet/), generates the
# checks from verif/formal/checks.cfg and runs them. FORMAL_TIMEOUT (seconds)
# limits each check; a check that hits it is reported as TIMEOUT.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$1"
dir=$(cd "$1" && pwd)/formal-${HORNET_ISA:-rv32imf}
jobs=$2
shift 2
core=$dir/cores/hornet

rm -rf "$dir"
mkdir -p "$core"
ln -s "$root/verif/riscv-formal/checks" "$dir/checks"
ln -s "$root/verif/riscv-formal/insns" "$dir/insns"
isa=${HORNET_ISA:-rv32imf}
ext=${isa#rv32i}
case $ext in *m*) rv_m=1;; *) rv_m=0;; esac
case $ext in *f*) rv_f=1;; *) rv_f=0;; esac
misa=$(printf "32'h%08X" $((0x40000100 | rv_m << 12 | rv_f << 5)))
if [ $rv_m = 1 ]; then formal_isa=rv32im; else formal_isa=rv32i; fi
sed -e "s|%RV_M%|$rv_m|; s|%RV_F%|$rv_f|; s|%MISA%|$misa|g" "$root/verif/formal/wrapper.sv" > "$core/wrapper.sv"
sed -e "s|%RTL%|$root/rtl|g; s|%ISA%|$formal_isa|" "$root/verif/formal/checks.cfg" > "$core/checks.cfg"
echo "formal: core $isa (RV_M=$rv_m RV_F=$rv_f, misa $misa), riscv-formal isa $formal_isa"

cd "$core"
python3 ../../checks/genchecks.py > genchecks.log
if [ "${FORMAL_TIMEOUT:-0}" -gt 0 ]; then
    sed -i "/^\[options\]/a timeout $FORMAL_TIMEOUT" checks/*.sby
fi
make -k -s -C checks -j"$jobs" "$@" > make.log 2>&1 || true
python3 "$root/scripts/formal_summary.py" checks "$@"
