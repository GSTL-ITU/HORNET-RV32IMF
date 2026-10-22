#!/usr/bin/env python3
"""Compares the bytes the firmware sent in a SoC simulation (+uart_hex log)
with test/label_results.txt: check_sim.py <sim log> <label_results.txt>"""
import re
import sys

got = [int(m.group(1), 16) for m in re.finditer(r"UART byte ([0-9a-f]{2})", open(sys.argv[1]).read())]
want = [int(l) for l in open(sys.argv[2]) if l.strip()]
results = got[1:]  # the first byte is the boot self-test
ok = len(results) > 0 and results == want[:len(results)]
print("MLP: %d samples, results %s, expected %s: %s" % (len(results), results, want[:len(results)], "PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
