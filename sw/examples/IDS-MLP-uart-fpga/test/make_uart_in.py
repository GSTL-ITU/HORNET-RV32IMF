#!/usr/bin/env python3
"""Writes the first N input vectors of inputs.txt as the UART byte stream the
firmware expects (122 little-endian floats per sample), for the SoC testbench:
  make_uart_in.py inputs.txt N out.bin"""
import struct
import sys

vectors = []
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip().strip("{").strip("};")
        if line:
            vectors.append([float(p.strip().rstrip("f")) for p in line.split(",") if p.strip()])
with open(sys.argv[3], "wb") as f:
    for v in vectors[:int(sys.argv[2])]:
        f.write(struct.pack("<%df" % len(v), *v))
