#!/usr/bin/env python3
"""Build and run the SoC test programs (sw/tests/*) on the SoC testbench.

  run_sw_tests.py --sim build/sim/soc/Vsoc_tb [-j 4] [--tests hello,irq]

A test passes when it exits with 0 (system control EXIT register). A file
uart_in.txt in the test directory is sent to the UART receiver. Logs go to
sw/tests/<name>/build/; the summary to build/sw-tests/summary.txt.
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(ROOT, "sw", "tests")


def run_one(sim, name):
    d = os.path.join(TESTS, name)
    r = subprocess.run(["make", "-s", "-C", d, "USE_DOCKER=0"], stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True)
    if r.returncode:
        return name, "BUILD", r.stdout[-1500:]
    base = os.path.join(d, "build", name)
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
    a = ap.parse_args()
    names = sorted(n for n in os.listdir(TESTS) if os.path.exists(os.path.join(TESTS, n, "Makefile")))
    if a.tests:
        names = [n for n in names if n in a.tests.split(",")]
    with ThreadPoolExecutor(max_workers=a.jobs) as pool:
        results = list(pool.map(lambda n: run_one(a.sim, n), names))
    out = os.path.join(ROOT, "build", "sw-tests")
    os.makedirs(out, exist_ok=True)
    lines = []
    for name, status, detail in results:
        lines.append("%-12s %-8s %s" % (name, status, detail if status == "PASS" else ""))
        if status != "PASS":
            print("%s %s\n%s" % (name, status, detail))
    passed = sum(1 for r in results if r[1] == "PASS")
    lines.append("%d/%d passed" % (passed, len(results)))
    with open(os.path.join(out, "summary.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    sys.exit(0 if passed == len(results) else 1)


if __name__ == "__main__":
    main()
