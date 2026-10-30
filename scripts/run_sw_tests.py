#!/usr/bin/env python3
"""Build and run the SoC test programs (sw/tests/*) on the SoC testbench.

  run_sw_tests.py --sim build/sim/soc-rv32imf-.../Vsoc_tb --isa rv32imf [-j 4] [--tests hello,irq]

A test passes when it exits with 0 (system control EXIT register). A file
uart_in.txt in the test directory is sent to the UART receiver. Programs are
built for --isa (the configuration of the simulated SoC); a test whose
Makefile says REQUIRES = f (or m) is skipped on a configuration without that
extension. Logs go to sw/tests/<name>/build/<isa>/; the summary to
build/<isa>/sw-tests/summary.txt.
"""
import argparse
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(ROOT, "sw", "tests")


def requires(name):
    with open(os.path.join(TESTS, name, "Makefile")) as f:
        m = re.search(r"^REQUIRES\s*[:?]?=\s*(.*)$", f.read(), re.M)
    return m.group(1).split() if m else []


def run_one(sim, isa, name):
    d = os.path.join(TESTS, name)
    missing = [e for e in requires(name) if e not in isa[len("rv32i"):]]
    if missing:
        return name, "SKIP", "needs " + ",".join(missing)
    out = os.path.join("build", isa)
    r = subprocess.run(["make", "-s", "-C", d, "USE_DOCKER=0", "ISA=" + isa, "OUT=" + out], stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True)
    if r.returncode:
        return name, "BUILD", r.stdout[-1500:]
    base = os.path.join(d, out, name)
    cmd = [sim, "+imem=" + base + ".imem.hex", "+dmem=" + base + ".dmem.hex", "+uart_log=" + base + ".uart.log"]
    if os.path.exists(os.path.join(d, "uart_in.txt")):
        cmd.append("+uart_in=" + os.path.join(d, "uart_in.txt"))
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=1800)
    with open(base + ".sim.log", "w") as f:
        f.write(" ".join(cmd) + "\n" + r.stdout)
    last = [l for l in r.stdout.splitlines() if l.startswith(("PASS", "FAIL", "TIMEOUT"))]
    status = last[0].split()[0] if last else "ERROR"
    return name, status, (last[0] if last else r.stdout[-1500:])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sim", required=True)
    ap.add_argument("-j", "--jobs", type=int, default=4)
    ap.add_argument("--tests", default="")
    ap.add_argument("--isa", default="rv32imf", choices=["rv32i", "rv32im", "rv32imf"])
    a = ap.parse_args()
    names = sorted(n for n in os.listdir(TESTS) if os.path.exists(os.path.join(TESTS, n, "Makefile")))
    if a.tests:
        names = [n for n in names if n in a.tests.split(",")]
    with ThreadPoolExecutor(max_workers=a.jobs) as pool:
        results = list(pool.map(lambda n: run_one(a.sim, a.isa, n), names))
    out = os.path.join(ROOT, "build", a.isa, "sw-tests")
    os.makedirs(out, exist_ok=True)
    lines = []
    for name, status, detail in results:
        lines.append("%-12s %-8s %s" % (name, status, detail if status in ("PASS", "SKIP") else ""))
        if status not in ("PASS", "SKIP"):
            print("%s %s\n%s" % (name, status, detail))
    passed = sum(1 for r in results if r[1] == "PASS")
    skipped = sum(1 for r in results if r[1] == "SKIP")
    lines.append("%d/%d passed, %d skipped (isa=%s)" % (passed, len(results) - skipped, skipped, a.isa))
    with open(os.path.join(out, "summary.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    sys.exit(0 if passed + skipped == len(results) else 1)


if __name__ == "__main__":
    main()
