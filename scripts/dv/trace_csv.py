#!/usr/bin/env python3
"""Trace logs to CSV and CSV comparison (RISCV-DV flow, ISMSIT 2025 paper section III-D).

  trace_csv.py convert --format hornet|spike --log <log> --csv <out.csv> [--dump <objdump>] [--riscv-dv <out.csv>]
                       [--tohost <address>]
  trace_csv.py compare <hornet.csv> <spike.csv> [--names hornet spike] [--log <compare.log>]
  trace_csv.py spike-reg-first <spike.log> <out.log>

convert reads the HORNET tracer log (tb/hornet_tb.sv, +trace=) or Spike's
commit log (--log-commits, with or without -l) and writes one CSV row per
retired instruction:

  idx, pc, binary, disasm, rd, rd_val, fflags, mem_addr, mem_data, trap

rd is x<n> or f<n> (x0 writes are not listed), fflags the accumulated flags
after an FP instruction that raised one, mem_addr/mem_data the byte address of
a load or store and the store data. Instructions that trap are not retired in
Spike's log, so they are dropped from both. --dump adds the disassembly from an
objdump listing. --riscv-dv also writes the trace in RISCV-DV's own CSV format
(scripts/riscv_trace_csv.py), so that riscv-dv's instr_trace_compare.py can
compare it with the output of riscv-dv's spike_log_to_trace_csv.py.

compare checks both CSVs row by row (same PC, instruction, register write,
flags and memory access). Reads of cycle, time, mcycle and marchid differ by
design: they are reported as warnings. Instructions that only one side retired
after the other side's end (Spike runs a few instructions after the tohost
write) are warnings too. Result: PASS, PASS with warnings or FAIL.
"""
import argparse
import csv
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from run_tests import BASE, masked  # noqa: E402

FIELDS = ["idx", "pc", "binary", "disasm", "rd", "rd_val", "fflags", "mem_addr", "mem_data", "trap"]

ABI = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
       "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"]
FABI = ["ft0", "ft1", "ft2", "ft3", "ft4", "ft5", "ft6", "ft7", "fs0", "fs1", "fa0", "fa1", "fa2", "fa3",
        "fa4", "fa5", "fa6", "fa7", "fs2", "fs3", "fs4", "fs5", "fs6", "fs7", "fs8", "fs9", "fs10", "fs11",
        "ft8", "ft9", "ft10", "ft11"]


def read_dump(path):
    """pc -> disassembly from an objdump -d listing."""
    dis = {}
    if not path:
        return dis
    with open(path) as f:
        for line in f:
            m = re.match(r"\s*([0-9a-f]+):\s+[0-9a-f]{8}\s+(.*)$", line)
            if m:
                dis[int(m.group(1), 16)] = m.group(2).split("#")[0].strip().replace("\t", " ")
    return dis


def parse_fields(fields, keep_fflags):
    row = {"rd": "", "rd_val": "", "fflags": "", "mem_addr": "", "mem_data": ""}
    i = 0
    while i < len(fields):
        t = fields[i]
        if re.fullmatch(r"[xf]\d+", t):
            if t != "x0":
                row["rd"], row["rd_val"] = t, "%08x" % int(fields[i + 1], 16)
            i += 2
        elif t == "mem":
            row["mem_addr"] = "%08x" % int(fields[i + 1], 16)
            if i + 2 < len(fields) and fields[i + 2].startswith("0x"):
                row["mem_data"] = "%x" % int(fields[i + 2], 16)
                i += 3
            else:
                i += 2
        elif t == "c1_fflags":
            if keep_fflags:
                row["fflags"] = "%02x" % int(fields[i + 1], 16)
            i += 2
        elif re.fullmatch(r"c\d+_\w+", t):
            i += 2
        else:
            i += 1
    return row


def read_log(path, fmt, stop_at_ecall=False, tohost=None):
    """Rows of the retired instructions; stop_at_ecall ends at the first ECALL
    (RISCV-DV's convention: the test ends with an ECALL into its handler),
    tohost before the first store to that address (the testbench stops there,
    Spike keeps running until its host interface sees the write)."""
    rows = []
    with open(path) as f:
        for line in f:
            if stop_at_ecall and re.search(r"\(0x00000073\)", line):
                break
            if fmt == "spike":
                m = re.match(r"core\s+\d+: \d+ 0x([0-9a-f]+) \(0x([0-9a-f]+)\)(.*)", line)
                trap = False
            else:
                trap = line.startswith("trap ")
                line = line[5:] if line.startswith(("trap ", "intr ")) else line
                m = re.match(r"0x([0-9a-f]+) \(0x([0-9a-f]+)\)(.*)", line)
            if not m:
                continue
            pc, insn = int(m.group(1), 16), int(m.group(2), 16)
            if pc < BASE or trap:
                continue  # Spike's boot ROM; trapping instructions (not in Spike's commit log)
            row = parse_fields(m.group(3).split(), (insn & 0x7f) != 0x73)
            if tohost is not None and row["mem_data"] and int(row["mem_addr"], 16) == tohost:
                break
            row.update(pc="%08x" % pc, binary="%08x" % insn, trap="0")
            rows.append(row)
    for i, r in enumerate(rows):
        r["idx"] = str(i)
    return rows


def write_csv(rows, path, dis):
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        for r in rows:
            r["disasm"] = dis.get(int(r["pc"], 16), "")
            w.writerow(r)


def write_riscv_dv_csv(rows, path):
    """RISCV-DV trace CSV (riscv_trace_csv.py): gpr as <abi name>:<value>."""
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["pc", "instr", "gpr", "csr", "binary", "mode", "instr_str",
                                          "operand", "pad"])
        w.writeheader()
        for r in rows:
            if not r["rd"]:
                continue  # riscv-dv lists instructions that write a register
            n = int(r["rd"][1:])
            name = (ABI if r["rd"][0] == "x" else FABI)[n]
            w.writerow({"pc": r["pc"], "instr": r["disasm"].split(" ")[0], "gpr": "%s:%s" % (name, r["rd_val"]),
                        "csr": "fflags:%s" % r["fflags"] if r["fflags"] else "", "binary": r["binary"],
                        "mode": "3", "instr_str": r["disasm"], "operand": "", "pad": ""})


def read_csv(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


KEYS = ["pc", "binary", "rd", "rd_val", "fflags", "mem_addr", "mem_data"]


def compare(a, b, names, out, limit=10):
    errors = []
    warnings = []
    n = min(len(a), len(b))
    for i in range(n):
        x, y = a[i], b[i]
        if x["pc"] != y["pc"] or x["binary"] != y["binary"]:
            errors.append("%d: instruction stream differs: %s %s %s / %s %s %s" % (
                i, names[0], x["pc"], x["binary"], names[1], y["pc"], y["binary"]))
            break  # the traces are out of step from here on
        diff = [k for k in KEYS if x[k] != y[k]]
        if not diff:
            continue
        if masked(int(x["binary"], 16)) and set(diff) <= {"rd_val"}:
            warnings.append("%d: pc %s %s reads a counter or ID CSR that differs by design: %s %s, %s %s" % (
                i, x["pc"], x["disasm"], names[0], x["rd_val"], names[1], y["rd_val"]))
            continue
        errors.append("%d: pc %s %s (%s): %s" % (i, x["pc"], x["disasm"] or y["disasm"], x["binary"], ", ".join(
            "%s %s=%s %s=%s" % (k, names[0], x[k] or "-", names[1], y[k] or "-") for k in diff)))
    if not errors and len(a) != len(b):
        longer, rest = (names[0], a[n:]) if len(a) > len(b) else (names[1], b[n:])
        msg = "%d instructions only in %s after the end of the other trace (from pc %s)" % (
            len(rest), longer, rest[0]["pc"])
        # the end of a test: Spike executes a few instructions after the tohost write
        (warnings if len(rest) <= 8 else errors).append(msg)
    if errors:
        result = "FAIL"
    elif warnings:
        result = "PASS with warnings"
    else:
        result = "PASS"
    lines = ["%s: %d instructions, %s: %d instructions, %d compared" % (names[0], len(a), names[1], len(b), n)]
    lines += ["ERROR   " + e for e in errors[:limit]]
    if len(errors) > limit:
        lines.append("... %d more errors" % (len(errors) - limit))
    lines += ["WARNING " + w for w in warnings[:limit]]
    if len(warnings) > limit:
        lines.append("... %d more warnings" % (len(warnings) - limit))
    lines.append("RESULT: " + result)
    text = "\n".join(lines) + "\n"
    if out:
        with open(out, "w") as f:
            f.write(text)
    return result, text


def spike_reg_first(src, dst):
    """Copy of a Spike log with the register write before the CSR writes in each
    commit line: Spike prints "c1_fflags 0x.. f9 0x..", RISCV-DV's
    spike_log_to_trace_csv.py only recognises a register right after the
    instruction word and would drop these FP instructions."""
    with open(src) as f, open(dst, "w") as g:
        for line in f:
            m = re.match(r"(core\s+\d+: \d+ 0x[0-9a-f]+ \(0x[0-9a-f]+\))(.*)$", line)
            if m:
                fields = m.group(2).split()
                pairs = [fields[i:i + 2] for i in range(0, len(fields) - 1, 2)]
                regs = [p for p in pairs if re.fullmatch(r"[xf]\d+", p[0])]
                if regs and pairs and pairs[0] not in regs and len(pairs) * 2 == len(fields):
                    pairs = regs + [p for p in pairs if p not in regs]
                    line = m.group(1) + " " + " ".join(" ".join(p) for p in pairs) + "\n"
            g.write(line)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("convert")
    c.add_argument("--format", choices=["hornet", "spike"], required=True)
    c.add_argument("--log", required=True)
    c.add_argument("--csv", required=True)
    c.add_argument("--dump", default="")
    c.add_argument("--riscv-dv", default="")
    c.add_argument("--tohost", default="", help="end before the first store to this address")
    r = sub.add_parser("spike-reg-first")
    r.add_argument("src")
    r.add_argument("dst")
    p = sub.add_parser("compare")
    p.add_argument("csv", nargs=2)
    p.add_argument("--names", nargs=2, default=["hornet", "spike"])
    p.add_argument("--log", default="")
    a = ap.parse_args()
    if a.cmd == "convert":
        tohost = int(a.tohost, 0) if a.tohost else None
        rows = read_log(a.log, a.format, tohost=tohost)
        write_csv(rows, a.csv, read_dump(a.dump))
        if a.riscv_dv:
            dv_rows = read_log(a.log, a.format, stop_at_ecall=True, tohost=tohost)
            write_csv(dv_rows, os.devnull, read_dump(a.dump))  # fills the disassembly
            write_riscv_dv_csv(dv_rows, a.riscv_dv)
        print("%s: %d instructions -> %s" % (a.log, len(rows), a.csv))
    elif a.cmd == "spike-reg-first":
        spike_reg_first(a.src, a.dst)
    else:
        result, text = compare(read_csv(a.csv[0]), read_csv(a.csv[1]), a.names, a.log)
        sys.stdout.write(text)
        sys.exit(0 if result != "FAIL" else 1)


if __name__ == "__main__":
    main()
