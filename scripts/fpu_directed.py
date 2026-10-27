#!/usr/bin/env python3
"""Directed FPU vectors for tb/fpu_tb.sv (same format as fpu_vectors.py)
   <op> <rm> <a> <b> <c> <result> <flags>

The cases target the bug classes the RISCV-DV environment found in the FPU
(Creating a Verification Environment Using RISCV-DV..., section IV):

  paper    0x4BB84A00 - 0x3F800001 (equation 2) and its mirrored forms
  grs      add/sub with the addend around the guard, round and sticky positions
  tiny     add/sub/mul with subnormal or smallest-normal operands and results
  ovf      results around the largest finite value and the subnormal range
  div      subnormal dividends and divisors
  sqrt     subnormal inputs (every exponent, random and boundary mantissas)
  cvt      FCVT.W[U].S around 0, +-2^31, 2^32 and the infinities

Expected values come from an exact rational model of IEEE 754 binary32
(tininess after rounding, RISC-V canonical NaN and conversion results); the
model checks itself against TestFloat before writing anything.

  fpu_directed.py --out build/fpu/directed.txt [--count 20000] [--seed 1]
"""
import argparse
import math
import random
import subprocess
import sys
from fractions import Fraction

OPS = {"ADD": 0, "SUB": 1, "MUL": 2, "DIV": 7, "SQRT": 8, "CVTWS": 20, "CVTWUS": 21}
RMS = (0, 1, 2, 3, 4)  # RNE RTZ RDN RUP RMM
NV, DZ, OF, UF, NX = 0x10, 0x08, 0x04, 0x02, 0x01
NEG = 0x80000000
QNAN = 0x7fc00000


def decode(x):
    """Finite binary32 as an exact fraction."""
    e = (x >> 23) & 0xff
    m = x & 0x7fffff
    v = Fraction(m, 1 << 23) * Fraction(2) ** -126 if e == 0 else \
        Fraction(m | 1 << 23, 1 << 23) * Fraction(2) ** (e - 127)
    return -v if x >> 31 else v


def is_nan(x):
    return (x >> 23) & 0xff == 0xff and x & 0x7fffff


def is_inf(x):
    return x & 0x7fffffff == 0x7f800000


def is_zero(x):
    return x & 0x7fffffff == 0


def ilog2(a):
    """floor(log2(a)) for a positive fraction"""
    e = a.numerator.bit_length() - a.denominator.bit_length()
    if Fraction(2) ** e > a:
        e -= 1
    return e


def round_int(n, rem, sticky, sign, rm):
    """Integer part n with fraction rem in [0, 1) (sticky: the true value is slightly above)."""
    if rem == 0 and not sticky:
        return n, False
    half = rem > Fraction(1, 2) or (rem == Fraction(1, 2) and sticky)
    tie = rem == Fraction(1, 2) and not sticky
    up = {0: half or (tie and n & 1), 1: False, 2: sign, 3: not sign, 4: half or tie}[rm]
    return n + (1 if up else 0), True


def round_f32(v, rm, sticky=False):
    """Rounds a nonzero exact value (plus an optional sticky bit) to binary32."""
    sign = v < 0
    a = -v if sign else v
    s = NEG if sign else 0

    def at(e):
        m = a / Fraction(2) ** (e - 23)
        n = m.numerator // m.denominator
        return round_int(n, m - n, sticky, sign, rm)

    e_true = ilog2(a)
    # tininess after rounding: round to 24 bits with an unbounded exponent
    n_u, nx = at(e_true)
    e_u = e_true + (1 if n_u == 1 << 24 else 0)
    tiny = e_u < -126
    e = max(e_true, -126)
    n, nx = at(e)
    if n == 1 << 24:
        n >>= 1
        e += 1
    if e > 127:
        to_inf = rm in (0, 4) or (rm == 2 and sign) or (rm == 3 and not sign)
        return (s | 0x7f800000 if to_inf else s | 0x7f7fffff), OF | NX
    flags = (NX if nx else 0) | (UF if tiny and nx else 0)
    if n < 1 << 23:  # subnormal or zero
        return s | n, flags
    return s | (e + 127) << 23 | (n & 0x7fffff), flags


def ref_arith(op, rm, x, y):
    """Reference for finite nonzero inputs; None for cases the model does not cover."""
    if any(is_nan(t) or is_inf(t) for t in (x, y)):
        return None
    if op == "SQRT":
        if is_zero(x):
            return x, 0
        if x >> 31:
            return QNAN, NV
        a = decode(x)
        k = 200  # a * 4^k is an integer for every binary32
        n = a * Fraction(4) ** k
        assert n.denominator == 1
        r = math.isqrt(n.numerator)
        return round_f32(Fraction(r, 1 << k), rm, r * r != n.numerator)
    if is_zero(x) or is_zero(y):
        return None
    a, b = decode(x), decode(y)
    if op == "ADD" or op == "SUB":
        v = a + b if op == "ADD" else a - b
        if v == 0:
            return (NEG if rm == 2 else 0), 0
        return round_f32(v, rm)
    if op == "MUL":
        return round_f32(a * b, rm)
    if op == "DIV":
        return round_f32(a / b, rm)
    return None


def ref_cvt(op, rm, x):
    """FCVT.W.S / FCVT.WU.S with the RISC-V results for NaN and out-of-range values."""
    unsigned = op == "CVTWUS"
    lo, hi = (0, (1 << 32) - 1) if unsigned else (-(1 << 31), (1 << 31) - 1)
    if is_nan(x):
        return hi & 0xffffffff, NV
    if is_inf(x):
        return (lo if x >> 31 else hi) & 0xffffffff, NV
    v = decode(x)
    sign = v < 0
    a = -v if sign else v
    n = a.numerator // a.denominator
    r, nx = round_int(n, a - n, False, sign, rm)
    r = -r if sign else r
    if r < lo or r > hi:
        return (lo if sign else hi) & 0xffffffff, NV
    return r & 0xffffffff, NX if nx else 0


def f32(sign, exp, mant):
    return (sign << 31) | (exp << 23) | (mant & 0x7fffff)


def rand_norm(rng, elo=1, ehi=254):
    return f32(rng.getrandbits(1), rng.randint(elo, ehi), rng.getrandbits(23))


def rand_sub(rng):
    """A subnormal with a mantissa of random length (from a single bit to all 23)."""
    m = rng.getrandbits(rng.randint(1, 23)) or 1
    return f32(rng.getrandbits(1), 0, m)


def edge_mant(rng):
    return rng.choice([0, 1, 2, 0x7fffff, 0x7ffffe, 0x400000, 0x3fffff, 0x400001, rng.getrandbits(23)])


def selfcheck():
    """The model must agree with TestFloat on every level-1 case it covers."""
    funcs = {"f32_add": "ADD", "f32_sub": "SUB", "f32_mul": "MUL", "f32_div": "DIV", "f32_sqrt": "SQRT",
             "f32_to_i32": "CVTWS", "f32_to_ui32": "CVTWUS"}
    names = {0: "-rnear_even", 1: "-rminMag", 2: "-rmin", 3: "-rmax", 4: "-rnear_maxMag"}
    checked = 0
    for func, op in funcs.items():
        for rm in RMS:
            cmd = ["testfloat_gen", "-tininessafter", "-level", "1", names[rm]]
            if op.startswith("CVT"):
                cmd.append("-exact")
            out = subprocess.run(cmd + [func], capture_output=True, text=True, check=True).stdout
            for line in out.splitlines():
                v = [int(t, 16) for t in line.split()]
                if op.startswith("CVT"):
                    got = ref_cvt(op, rm, v[0])
                    want = (v[1], v[2])
                elif op == "SQRT":
                    got = ref_arith(op, rm, v[0], 0)
                    want = (v[1], v[2])
                else:
                    got = ref_arith(op, rm, v[0], v[1])
                    want = (v[2], v[3])
                if got is None:
                    continue
                if got != want:
                    sys.exit("model mismatch %s rm=%d %s: model %08x/%02x testfloat %08x/%02x"
                             % (func, rm, line, got[0], got[1], want[0], want[1]))
                checked += 1
    print("model agrees with TestFloat on %d cases" % checked)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--count", type=int, default=20000, help="random cases per group and rounding mode")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--no-selfcheck", action="store_true")
    a = ap.parse_args()
    if not a.no_selfcheck:
        selfcheck()
    rng = random.Random(a.seed)
    lines = []
    groups = {}

    def add(group, op, rm, x, y=0):
        r = ref_cvt(op, rm, x) if op.startswith("CVT") else ref_arith(op, rm, x, y)
        if r is None:
            return
        lines.append("%02x %x %08x %08x %08x %08x %02x" % (OPS[op], rm, x, y, 0, r[0], r[1]))
        groups[group] = groups.get(group, 0) + 1

    for rm in RMS:
        # equation (2) of the paper and its mirrored forms
        for x, y in ((0x4BB84A00, 0x3F800001), (0xCBB84A00, 0xBF800001), (0x3F800001, 0x4BB84A00)):
            add("paper", "SUB", rm, x, y)
            add("paper", "ADD", rm, x, y ^ NEG)
        # the same pattern at every exponent: a large value minus slightly more than half an ulp
        for e in range(24, 254):
            for m in (0x384A00, 0x0, 0x7fffff, rng.getrandbits(23)):
                x = f32(0, e, m)
                for d in (-1, 0, 1):
                    add("paper", "SUB", rm, x, f32(0, e - 23, max(0, d)))
                    add("paper", "SUB", rm, x, f32(0, e - 24, d & 0x7fffff))

        for _ in range(a.count):
            # addend aligned around guard/round/sticky: exponent difference 0..30
            x = rand_norm(rng, 30, 224)
            d = rng.randint(0, 30)
            y = f32(rng.getrandbits(1), ((x >> 23) & 0xff) - d, edge_mant(rng))
            add("grs", rng.choice(["ADD", "SUB"]), rm, x, y)
            # near-cancellation (exponents equal or one apart)
            y = f32(rng.getrandbits(1), ((x >> 23) & 0xff) - rng.randint(0, 1), rng.getrandbits(23))
            add("grs", rng.choice(["ADD", "SUB"]), rm, x, y)

            # tiny operands and results
            s = rand_sub(rng)
            add("tiny", rng.choice(["ADD", "SUB"]), rm, s, rng.choice([rand_sub(rng), f32(rng.getrandbits(1), rng.randint(1, 3), edge_mant(rng))]))
            add("tiny", "MUL", rm, rand_norm(rng, 1, 126), rand_norm(rng, 1, 30))
            add("tiny", "MUL", rm, s, rand_norm(rng, 100, 180))

            # around overflow and the bottom of the subnormal range
            add("ovf", "MUL", rm, rand_norm(rng, 190, 254), rand_norm(rng, 120, 140))
            add("ovf", rng.choice(["ADD", "SUB"]), rm, f32(rng.getrandbits(1), 254, edge_mant(rng)),
                f32(rng.getrandbits(1), rng.randint(225, 254), edge_mant(rng)))
            add("ovf", "MUL", rm, rand_norm(rng, 1, 40), rand_norm(rng, 60, 105))
            add("ovf", "DIV", rm, rand_norm(rng, 1, 30), rand_norm(rng, 150, 254))

            # division with subnormal dividend and/or divisor
            add("div", "DIV", rm, rand_sub(rng), rand_norm(rng))
            add("div", "DIV", rm, rand_norm(rng), rand_sub(rng))
            add("div", "DIV", rm, rand_sub(rng), rand_sub(rng))
            add("div", "DIV", rm, rand_sub(rng), f32(rng.getrandbits(1), rng.randint(1, 30), edge_mant(rng)))

            # square root of subnormals and of normals
            add("sqrt", "SQRT", rm, rand_sub(rng) & 0x7fffffff)
            add("sqrt", "SQRT", rm, f32(0, 0, rng.getrandbits(23) or 1))
            add("sqrt", "SQRT", rm, rand_norm(rng) & 0x7fffffff)

        # every subnormal exponent position with boundary mantissas
        for k in range(23):
            for m in (1 << k, (1 << (k + 1)) - 1, (1 << k) | 1, ((1 << (k + 1)) - 1) ^ 1):
                add("sqrt", "SQRT", rm, f32(0, 0, m))
                add("div", "DIV", rm, f32(0, 0, m), 0x3f800001)
                add("div", "DIV", rm, f32(0, 0, m), 0x3f7fffff)
                add("div", "DIV", rm, 0x3f800000, f32(0, 0, m))

        # conversions around 0, +-2^31, 2^32 and the infinities
        for op in ("CVTWS", "CVTWUS"):
            for e in list(range(110, 160)):
                for m in (0, 1, 0x7fffff, 0x7ffffe, 0x400000, 0x3fffff, 0x400001, rng.getrandbits(23)):
                    add("cvt", op, rm, f32(0, e, m))
                    add("cvt", op, rm, f32(1, e, m))
            for x in (0x7f800000, 0xff800000, 0x7f7fffff, 0xff7fffff, 0x7fc00000, 0xffc00000, 0x7f800001,
                      0x4f000000, 0xcf000000, 0x4effffff, 0xceffffff, 0xcf000001, 0x4f800000, 0x4f7fffff,
                      0x00000001, 0x80000001, 0x3f000000, 0xbf000000, 0x3fc00000, 0xbfc00000, 0xbf7fffff):
                add("cvt", op, rm, x)

    with open(a.out, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("%d vectors: %s" % (len(lines), ", ".join("%s %d" % kv for kv in groups.items())))


if __name__ == "__main__":
    main()
