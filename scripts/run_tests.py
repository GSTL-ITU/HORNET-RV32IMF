#!/usr/bin/env python3
"""Build and run programs on the HORNET core testbench, optionally against Spike.

  run_tests.py --sim build/sim/core-rv32imf/Vhornet_tb --isa rv32imf --spike
  run_tests.py --sim ... --isa rv32im --random 200 --seed 1 --spike --mem-stall 30

--isa is the core configuration (rv32i, rv32im, rv32imf). It selects
the riscv-tests suites (ui and mi always, um with M, uf with F), the compiler
-march and Spike's --isa, so instructions of a missing extension trap in both.

Every test gets <workdir>/<suite>/<name>.{elf,hex,dump,rtl.log,spike.log,sim.log}.
The summary is printed and written to <workdir>/summary.txt.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(ROOT, "verif", "riscv-tests")
BASE = 0x80000000
MEM_SIZE = 0x400000

ISAS = ("rv32i", "rv32im", "rv32imf")


def march(isa):
    return isa + "_zicsr_zifencei"


def spike_isa(isa):
    return isa + "_zicsr_zifencei_zicntr"


def default_suites(isa):
    ext = isa[len("rv32i"):]
    return ",".join(["ui"] + (["um"] if "m" in ext else []) + (["uf"] if "f" in ext else []) + ["mi"])

SPIKE_ARGS = ["--priv=m", "--pmpregions=0", "--triggers=0", "--wfi-as-nop"]

# reasons are printed in the summary
SKIP = {
    "rv32mi-p-pmpaddr": "no PMP",
    "rv32ui-p-ma_data": "misaligned accesses trap (ADR-0006)",
}

# CSRs whose values differ from Spike by design: cycle, time, mcycle, marchid
MASKED_CSRS = {0xC00, 0xC01, 0xC80, 0xC81, 0xB00, 0xB80, 0xF12}

CC = "riscv32-unknown-elf-gcc"


def run(cmd, **kw):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, **kw)


def build_test(src, out_dir, name, isa):
    elf = os.path.join(out_dir, name + ".elf")
    env = os.path.join(TESTS, "env", "p")
    r = run([CC, "-march=" + march(isa), "-mabi=ilp32", "-static", "-mcmodel=medany",
             "-fvisibility=hidden", "-nostdlib", "-nostartfiles",
             "-I" + env, "-I" + os.path.join(TESTS, "isa", "macros", "scalar"),
             "-T" + os.path.join(env, "link.ld"), src, "-o", elf])
    if r.returncode:
        raise RuntimeError("build failed:\n" + r.stdout)
    return elf


def prepare(elf):
    base = elf[:-4]
    with open(base + ".dump", "w") as f:
        subprocess.run(["riscv32-unknown-elf-objdump", "-d", elf], stdout=f, check=True)
    subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "elf2hex.py"), elf, base + ".hex",
                    "--base", hex(BASE), "--size", hex(MEM_SIZE)], check=True)
    sym = run(["riscv32-unknown-elf-nm", elf]).stdout
    m = re.search(r"^([0-9a-f]+) \w tohost$", sym, re.M)
    return int(m.group(1), 16) if m else BASE + 0x1000


def parse_line(fields, fp_flags=True):
    """[(kind, a, b)] from the register/memory fields of one trace line.

    fp_flags: keep c1_fflags (the accumulated flags after an FP instruction that
    raised one); off for CSR instructions, whose CSR writes are not compared."""
    out = []
    i = 0
    while i < len(fields):
        t = fields[i]
        if re.fullmatch(r"[xf]\d+", t):
            out.append((t, int(fields[i + 1], 16)))
            i += 2
        elif t == "mem":
            if i + 2 < len(fields) and fields[i + 2].startswith("0x"):
                out.append(("st", int(fields[i + 1], 16), int(fields[i + 2], 16)))
                i += 3
            else:
                out.append(("ld", int(fields[i + 1], 16)))
                i += 2
        elif t == "c1_fflags" and fp_flags:
            out.append((t, int(fields[i + 1], 16)))
            i += 2
        elif re.fullmatch(r"c\d+_\w+", t):
            i += 2  # other CSR writes are not compared
        else:
            i += 1
    return sorted(out)  # the order of the fields differs between Spike's log lines


def read_spike(path):
    trace = []
    with open(path) as f:
        for line in f:
            m = re.match(r"core\s+\d+: \d+ 0x([0-9a-f]+) \(0x([0-9a-f]+)\)(.*)", line)
            if not m:
                continue
            pc = int(m.group(1), 16)
            if pc < BASE:
                continue
            insn = int(m.group(2), 16)
            trace.append((pc, insn, parse_line(m.group(3).split(), (insn & 0x7f) != 0x73)))
    return trace


def read_rtl(path):
    trace = []
    with open(path) as f:
        for line in f:
            if line.startswith("trap "):
                continue
            line = line[5:] if line.startswith("intr ") else line
            m = re.match(r"0x([0-9a-f]+) \(0x([0-9a-f]+)\)(.*)", line)
            if m:
                trace.append((int(m.group(1), 16), int(m.group(2), 16), parse_line(m.group(3).split())))
    return trace


def masked(insn):
    return (insn & 0x7f) == 0x73 and (insn >> 12) & 7 != 0 and (insn >> 20) in MASKED_CSRS


def compare(rtl, spike):
    n = min(len(rtl), len(spike))
    if n == 0:
        return "empty trace"
    for i in range(n):
        a, b = rtl[i], spike[i]
        if masked(a[1]):
            a = (a[0], a[1], [e for e in a[2] if e[0][0] != "x"])
            b = (b[0], b[1], [e for e in b[2] if e[0][0] != "x"])
        if a != b:
            return "mismatch at %d:\n  rtl   %s\n  spike %s" % (i, fmt(a), fmt(b))
    return None


def fmt(e):
    parts = ["0x%08x (0x%08x)" % (e[0], e[1])]
    for x in e[2]:
        parts.append(" ".join(("0x%x" % v) if isinstance(v, int) else v for v in x))
    return " ".join(parts)


def run_one(args, suite, name, elf):
    base = elf[:-4]
    try:
        tohost = prepare(elf)
    except Exception as e:
        return name, "ERROR", str(e)
    cmd = [args.sim, "+hex=" + base + ".hex", "+trace=" + base + ".rtl.log", "+tohost=%x" % tohost,
           "+mem_stall=%d" % args.mem_stall, "+seed=%d" % args.seed, "+timeout=%d" % args.timeout]
    r = run(cmd, timeout=600)
    with open(base + ".sim.log", "w") as f:
        f.write(" ".join(cmd) + "\n" + r.stdout)
    res = [l for l in r.stdout.splitlines() if re.match(r"(PASS|FAIL|TIMEOUT|HANG)", l)]
    errors = [l for l in r.stdout.splitlines() if "RVFI ERROR" in l]
    if not res:
        return name, "ERROR", r.stdout[-2000:]
    status = res[0].split()[0]
    detail = res[0]
    if errors:
        return name, "FAIL", errors[0]
    if status != "PASS":
        return name, status, detail
    if args.spike:
        with open(base + ".spike.log", "w") as f:
            subprocess.run(["spike", "--isa=" + spike_isa(args.isa)] + SPIKE_ARGS + ["--log-commits", elf],
                           stdout=subprocess.DEVNULL, stderr=f, timeout=600)
        diff = compare(read_rtl(base + ".rtl.log"), read_spike(base + ".spike.log"))
        if diff:
            return name, "MISMATCH", diff
    return name, "PASS", detail


def collect(args):
    jobs = []
    for suite in args.suites.split(","):
        if not suite:
            continue
        sdir = os.path.join(TESTS, "isa", "rv32" + suite)
        out = os.path.join(args.workdir, "rv32" + suite)
        os.makedirs(out, exist_ok=True)
        for src in sorted(os.listdir(sdir)):
            if not src.endswith(".S"):
                continue
            name = "rv32%s-p-%s" % (suite, src[:-2])
            if args.tests and src[:-2] not in args.tests.split(","):
                continue
            jobs.append((suite, name, os.path.join(sdir, src), out))
    return jobs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sim", required=True)
    ap.add_argument("--isa", default="rv32imf", choices=ISAS)
    ap.add_argument("--suites", default="", help="default: every suite of --isa")
    ap.add_argument("--tests", default="")
    ap.add_argument("--spike", action="store_true")
    ap.add_argument("--mem-stall", type=int, default=0)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--timeout", type=int, default=2000000)
    ap.add_argument("--random", type=int, default=0, help="number of random programs")
    ap.add_argument("--random-kind", default="all")
    ap.add_argument("--programs", default="", help="directory with prebuilt *.elf files")
    ap.add_argument("--workdir", default="build/tests")
    ap.add_argument("-j", "--jobs", type=int, default=4)
    args = ap.parse_args()

    if not args.suites:
        args.suites = default_suites(args.isa)
    os.makedirs(args.workdir, exist_ok=True)
    work = []
    skipped = []
    if args.random:
        rdir = os.path.join(args.workdir, "random")
        shutil.rmtree(rdir, ignore_errors=True)  # no programs of an earlier run
        os.makedirs(rdir, exist_ok=True)
        r = run([sys.executable, os.path.join(ROOT, "scripts", "gen_random.py"), "--out", rdir,
                 "--count", str(args.random), "--seed", str(args.seed), "--kind", args.random_kind,
                 "--isa", args.isa])
        if r.returncode:
            sys.exit(r.stdout)
        for f in sorted(os.listdir(rdir)):
            if f.endswith(".elf"):
                work.append(("random", f[:-4], os.path.join(rdir, f)))
    elif args.programs:
        for f in sorted(os.listdir(args.programs)):
            if f.endswith(".elf"):
                work.append(("prog", f[:-4], os.path.join(args.programs, f)))
    else:
        for suite, name, src, out in collect(args):
            if name in SKIP:
                skipped.append((name, SKIP[name]))
                continue
            try:
                work.append((suite, name, build_test(src, out, name, args.isa)))
            except RuntimeError as e:
                print(name, e)
                sys.exit(1)

    results = []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futs = [pool.submit(run_one, args, s, n, e) for s, n, e in work]
        for f in futs:
            name, status, detail = f.result()
            results.append((name, status, detail))
            if status != "PASS":
                print("%-28s %s\n%s" % (name, status, detail))

    passed = sum(1 for r in results if r[1] == "PASS")
    lines = ["%-28s %s" % (n, s) for n, s, _ in results]
    lines += ["%-28s SKIP (%s)" % s for s in skipped]
    summary = "%d/%d passed, %d skipped (isa=%s, spike=%s, mem_stall=%d%%, seed=%d)" % (
        passed, len(results), len(skipped), args.isa, "yes" if args.spike else "no", args.mem_stall, args.seed)
    with open(os.path.join(args.workdir, "summary.txt"), "w") as f:
        f.write("\n".join(lines + [summary]) + "\n")
    print(summary)
    sys.exit(0 if passed == len(results) else 1)


if __name__ == "__main__":
    main()
