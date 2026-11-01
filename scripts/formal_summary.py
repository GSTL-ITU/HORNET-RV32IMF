#!/usr/bin/env python3
"""Summarise riscv-formal results: formal_summary.py <checks dir> [check ...]"""
import os
import sys


def status(d):
    for name, res in (("PASS", "PASS"), ("FAIL", "FAIL"), ("ERROR", "ERROR"), ("TIMEOUT", "TIMEOUT")):
        if os.path.exists(os.path.join(d, name)):
            return res
    log = os.path.join(d, "logfile.txt")
    if os.path.exists(log):
        text = open(log).read()
        if "DONE (PASS" in text:
            return "PASS"
        if "DONE (FAIL" in text:
            return "FAIL"
        if "TIMEOUT" in text:
            return "TIMEOUT"
        return "ERROR"
    return "NOT RUN"


def main():
    base = sys.argv[1]
    only = set(sys.argv[2:])
    checks = sorted(f[:-4] for f in os.listdir(base) if f.endswith(".sby"))
    if only:
        checks = [c for c in checks if c in only]
    res = {c: status(os.path.join(base, c)) for c in checks}
    for c in checks:
        if res[c] != "PASS":
            print("%-28s %s" % (c, res[c]))
    passed = sum(1 for r in res.values() if r == "PASS")
    with open(os.path.join(base, "..", "summary.txt"), "w") as f:
        for c in checks:
            f.write("%-28s %s\n" % (c, res[c]))
        f.write("%d/%d passed\n" % (passed, len(checks)))
    print("formal: %d/%d passed" % (passed, len(checks)))
    sys.exit(0 if passed == len(checks) else 1)


if __name__ == "__main__":
    main()
