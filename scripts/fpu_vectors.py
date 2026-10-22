#!/usr/bin/env python3
"""Test vectors for tb/fpu_tb.sv: one line per case, hex fields
   <op> <rm> <a> <b> <c> <result> <flags>

TestFloat (RISC-V specialisation, tininess after rounding) gives the arithmetic
operations; min/max, classify and sign injection come from the model below.

  fpu_vectors.py --out build/fpu/vectors.txt [--level 1] [--fma-step 40]
"""
import argparse
import random
import struct
import subprocess

OPS = {"ADD": 0, "SUB": 1, "MUL": 2, "MADD": 3, "MSUB": 4, "NMSUB": 5, "NMADD": 6, "DIV": 7,
       "SQRT": 8, "SGNJ": 9, "SGNJN": 10, "SGNJX": 11, "MIN": 12, "MAX": 13, "EQ": 14, "LT": 15,
       "LE": 16, "CLASS": 17, "CVTWS": 20, "CVTWUS": 21, "CVTSW": 22, "CVTSWU": 23}
RMS = {0: "-rnear_even", 1: "-rminMag", 2: "-rmin", 3: "-rmax", 4: "-rnear_maxMag"}
NEG = 0x80000000


def testfloat(func, rm, level, step=1, exact=False):
    """All cases of the level, or every step-th one."""
    cmd = ["testfloat_gen", "-tininessafter", "-level", str(level), RMS[rm]]
    if exact:
        cmd.append("-exact")
    p = subprocess.Popen(cmd + [func], stdout=subprocess.PIPE, text=True)
    for i, line in enumerate(p.stdout):
        if i % step == 0:
            yield [int(x, 16) for x in line.split()]
    p.wait()


def is_nan(x):
    return (x >> 23) & 0xff == 0xff and x & 0x7fffff


def is_snan(x):
    return is_nan(x) and not x & 0x400000


def as_float(x):
    return struct.unpack("<f", struct.pack("<I", x))[0]


def fclass(x):
    s = x >> 31
    e = (x >> 23) & 0xff
    f = x & 0x7fffff
    if e == 0xff:
        return (1 << 9 if f & 0x400000 else 1 << 8) if f else (1 << 0 if s else 1 << 7)
    if e == 0:
        return (1 << 3 if s else 1 << 4) if not f else (1 << 2 if s else 1 << 5)
    return 1 << 1 if s else 1 << 6


def minmax(a, b, is_max):
    flags = 0x10 if is_snan(a) or is_snan(b) else 0
    if is_nan(a) and is_nan(b):
        return 0x7fc00000, flags
    if is_nan(a):
        return b, flags
    if is_nan(b):
        return a, flags
    fa, fb = as_float(a), as_float(b)
    if fa == fb:  # +0 and -0
        if is_max:
            r = a if not a >> 31 else b
        else:
            r = a if a >> 31 else b
    else:
        r = (a if fa > fb else b) if is_max else (a if fa < fb else b)
    return r, flags


def specials():
    vals = [0x0, NEG, 0x1, 0x80000001, 0x7fffff, 0x807fffff, 0x800000, 0x80800000, 0x3f800000,
            0xbf800000, 0x7f7fffff, 0xff7fffff, 0x7f800000, 0xff800000, 0x7fc00000, 0xffc00000,
            0x7f800001, 0xff800001, 0x7fa00000, 0x40490fdb]
    return vals


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--level", type=int, default=1)
    ap.add_argument("--fma-step", type=int, default=40, help="keep every n-th f32_mulAdd case")
    ap.add_argument("--seed", type=int, default=1)
    a = ap.parse_args()
    random.seed(a.seed)
    lines = []

    def add(op, rm, x, y, z, r, fl):
        lines.append("%02x %x %08x %08x %08x %08x %02x" % (OPS[op], rm, x, y, z, r, fl))

    for rm in RMS:
        for v in testfloat("f32_add", rm, a.level):
            add("ADD", rm, v[0], v[1], 0, v[2], v[3])
        for v in testfloat("f32_sub", rm, a.level):
            add("SUB", rm, v[0], v[1], 0, v[2], v[3])
        for v in testfloat("f32_mul", rm, a.level):
            add("MUL", rm, v[0], v[1], 0, v[2], v[3])
        for v in testfloat("f32_mulAdd", rm, a.level, a.fma_step):
            x, y, z, r, fl = v
            add("MADD", rm, x, y, z, r, fl)
            add("MSUB", rm, x, y, z ^ NEG, r, fl)
            add("NMSUB", rm, x ^ NEG, y, z, r, fl)
            add("NMADD", rm, x ^ NEG, y, z ^ NEG, r, fl)
        for v in testfloat("f32_div", rm, a.level):
            add("DIV", rm, v[0], v[1], 0, v[2], v[3])
        for v in testfloat("f32_sqrt", rm, a.level):
            add("SQRT", rm, v[0], 0, 0, v[1], v[2])
        for v in testfloat("f32_to_i32", rm, a.level, exact=True):
            add("CVTWS", rm, v[0], 0, 0, v[1], v[2])
        for v in testfloat("f32_to_ui32", rm, a.level, exact=True):
            add("CVTWUS", rm, v[0], 0, 0, v[1], v[2])
        for v in testfloat("i32_to_f32", rm, a.level):
            add("CVTSW", rm, v[0], 0, 0, v[1], v[2])
        for v in testfloat("ui32_to_f32", rm, a.level):
            add("CVTSWU", rm, v[0], 0, 0, v[1], v[2])
    for v in testfloat("f32_eq", 0, a.level):
        add("EQ", 0, v[0], v[1], 0, v[2], v[3])
    for v in testfloat("f32_lt", 0, a.level):
        add("LT", 0, v[0], v[1], 0, v[2], v[3])
    for v in testfloat("f32_le", 0, a.level):
        add("LE", 0, v[0], v[1], 0, v[2], v[3])

    pairs = [(x, y) for x in specials() for y in specials()]
    pairs += [(random.getrandbits(32), random.getrandbits(32)) for _ in range(20000)]
    for x, y in pairs:
        for op in ("MIN", "MAX"):
            r, fl = minmax(x, y, op == "MAX")
            add(op, 0, x, y, 0, r, fl)
        add("SGNJ", 0, x, y, 0, (x & 0x7fffffff) | (y & NEG), 0)
        add("SGNJN", 0, x, y, 0, (x & 0x7fffffff) | (~y & NEG), 0)
        add("SGNJX", 0, x, y, 0, x ^ (y & NEG), 0)
        add("CLASS", 0, x, 0, 0, fclass(x), 0)

    with open(a.out, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("%d vectors" % len(lines))


if __name__ == "__main__":
    main()
