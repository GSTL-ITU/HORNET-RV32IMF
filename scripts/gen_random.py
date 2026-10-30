#!/usr/bin/env python3
"""Random RV32I[M][F] programs for co-simulation against Spike.

  gen_random.py --out build/random --count 200 --seed 1 [--kind all|int|fp] [--length 400] [--isa rv32imf]

--isa is the core configuration. Instructions of an extension the core does
not have are still generated, at a tenth of their normal rate: they must raise
illegal-instruction exceptions on the core as on Spike (run with the same
--isa). The programs are always assembled for rv32imf.

Registers x28-x31 are reserved: x29 points to the data buffer, x30 and x31
belong to the trap handler (it skips the trapping instruction and reads
mcause, so the cause appears in both traces). Sources are biased towards
recently written registers, so most instructions depend on one at distance
1-3 (forwarding, load-use, late producers, multi-cycle units). minstret is
cleared first because Spike counts its boot ROM.
"""
import argparse
import os
import random
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(ROOT, "verif", "riscv-tests")

XREGS = list(range(1, 28))
FREGS = list(range(32))
SPECIAL_F = [0x00000000, 0x80000000, 0x00000001, 0x807fffff, 0x00800000, 0x3f800000, 0xbf800000,
             0x7f7fffff, 0xff7fffff, 0x7f800000, 0xff800000, 0x7fc00000, 0x7fa00000, 0x4b000000,
             0xcf000000, 0x4f800000, 0x3effffff, 0x3f000000, 0x40490fdb, 0x34000000, 0x00ffffff]
SPECIAL_X = [0, 1, -1, 0x7fffffff, -0x80000000, 2, -2, 0x80, 0xffff, 0x12345678]

ALU_RR = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
ALU_RI = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
SHIFT_I = ["slli", "srli", "srai"]
MULDIV = ["mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu"]
BRANCH = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]
RM = ["rne", "rtz", "rdn", "rup", "rmm", "dyn"]
F_RR = ["fadd.s", "fsub.s", "fmul.s", "fdiv.s"]
F_SGNJ = ["fsgnj.s", "fsgnjn.s", "fsgnjx.s", "fmin.s", "fmax.s"]
F_CMP = ["feq.s", "flt.s", "fle.s"]
F_FMA = ["fmadd.s", "fmsub.s", "fnmsub.s", "fnmadd.s"]


class Gen:
    def __init__(self, rnd, kind, isa="rv32imf"):
        self.r = rnd
        self.kind = kind
        ext = isa[len("rv32i"):]
        self.has_m = "m" in ext
        self.has_f = "f" in ext
        self.recent_x = []
        self.recent_f = []
        self.lines = []
        self.label = 0

    def xsrc(self):
        if self.recent_x and self.r.random() < 0.6:
            return self.r.choice(self.recent_x[-3:])
        return self.r.choice(XREGS + [0])

    def fsrc(self):
        if self.recent_f and self.r.random() < 0.6:
            return self.r.choice(self.recent_f[-3:])
        return self.r.choice(FREGS)

    def xdst(self):
        d = self.r.choice(XREGS)
        self.recent_x.append(d)
        return d

    def fdst(self):
        d = self.r.choice(FREGS)
        self.recent_f.append(d)
        return d

    def emit(self, s):
        self.lines.append("    " + s)

    def rm(self):
        return self.r.choice(RM)

    def int_op(self):
        c = self.r.random()
        if c < 0.3:
            self.emit("%s x%d, x%d, x%d" % (self.r.choice(ALU_RR), self.xdst(), self.xsrc(), self.xsrc()))
        elif c < 0.45:
            self.emit("%s x%d, x%d, %d" % (self.r.choice(ALU_RI), self.xdst(), self.xsrc(), self.r.randint(-2048, 2047)))
        elif c < 0.5:
            self.emit("%s x%d, x%d, %d" % (self.r.choice(SHIFT_I), self.xdst(), self.xsrc(), self.r.randint(0, 31)))
        elif c < 0.55:
            self.emit("%s x%d, 0x%x" % (self.r.choice(["lui", "auipc"]), self.xdst(), self.r.randint(0, 0xfffff)))
        elif c < 0.7:
            if self.has_m or self.r.random() < 0.1:
                self.emit("%s x%d, x%d, x%d" % (self.r.choice(MULDIV), self.xdst(), self.xsrc(), self.xsrc()))
            else:
                self.emit("%s x%d, x%d, x%d" % (self.r.choice(ALU_RR), self.xdst(), self.xsrc(), self.xsrc()))
        elif c < 0.75:
            self.emit("li x%d, %d" % (self.xdst(), self.r.choice(SPECIAL_X)))
        else:
            self.mem_op(fp=False)

    def mem_op(self, fp):
        size = 4 if fp else self.r.choice([1, 2, 4])
        off = self.r.randrange(0, 1024, size)
        if self.r.random() < 0.04:
            off += self.r.randint(1, 3)  # misaligned: traps
        if fp:
            if self.r.random() < 0.5:
                self.emit("flw f%d, %d(x29)" % (self.fdst(), off))
            else:
                self.emit("fsw f%d, %d(x29)" % (self.fsrc(), off))
            return
        if self.r.random() < 0.5:
            op = {1: self.r.choice(["lb", "lbu"]), 2: self.r.choice(["lh", "lhu"]), 4: "lw"}[size]
            self.emit("%s x%d, %d(x29)" % (op, self.xdst(), off))
        else:
            op = {1: "sb", 2: "sh", 4: "sw"}[size]
            self.emit("%s x%d, %d(x29)" % (op, self.xsrc(), off))

    def fp_op(self):
        c = self.r.random()
        if c < 0.2:
            self.emit("%s f%d, f%d, f%d, %s" % (self.r.choice(F_RR), self.fdst(), self.fsrc(), self.fsrc(), self.rm()))
        elif c < 0.35:
            self.emit("%s f%d, f%d, f%d, f%d, %s" % (self.r.choice(F_FMA), self.fdst(), self.fsrc(), self.fsrc(),
                                                     self.fsrc(), self.rm()))
        elif c < 0.4:
            self.emit("fsqrt.s f%d, f%d, %s" % (self.fdst(), self.fsrc(), self.rm()))
        elif c < 0.5:
            self.emit("%s f%d, f%d, f%d" % (self.r.choice(F_SGNJ), self.fdst(), self.fsrc(), self.fsrc()))
        elif c < 0.57:
            self.emit("%s x%d, f%d, f%d" % (self.r.choice(F_CMP), self.xdst(), self.fsrc(), self.fsrc()))
        elif c < 0.62:
            self.emit("fclass.s x%d, f%d" % (self.xdst(), self.fsrc()))
        elif c < 0.68:
            self.emit("%s x%d, f%d, %s" % (self.r.choice(["fcvt.w.s", "fcvt.wu.s"]), self.xdst(), self.fsrc(), self.rm()))
        elif c < 0.74:
            self.emit("%s f%d, x%d, %s" % (self.r.choice(["fcvt.s.w", "fcvt.s.wu"]), self.fdst(), self.xsrc(), self.rm()))
        elif c < 0.8:
            self.emit("fmv.x.w x%d, f%d" % (self.xdst(), self.fsrc()))
        elif c < 0.88:
            r = self.xdst()
            self.emit("li x%d, 0x%x" % (r, self.r.choice(SPECIAL_F) ^ (self.r.getrandbits(3) if self.r.random() < 0.3 else 0)))
            self.emit("fmv.w.x f%d, x%d" % (self.fdst(), r))
        else:
            self.mem_op(fp=True)

    def csr_op(self):
        c = self.r.random()
        if c < 0.25:
            self.emit("csrr x%d, fflags" % self.xdst())
        elif c < 0.35:
            self.emit("csrrw x%d, fflags, x%d" % (self.xdst(), self.xsrc()))
        elif c < 0.5:
            v = self.r.choice([0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 5, 7])  # 5..7: dynamic rounding traps
            self.emit("csrrwi x%d, frm, %d" % (self.xdst(), v))
        elif c < 0.6:
            self.emit("csrr x%d, fcsr" % self.xdst())
        elif c < 0.75:
            self.emit("%s x%d, mscratch, x%d" % (self.r.choice(["csrrw", "csrrs", "csrrc"]), self.xdst(), self.xsrc()))
        elif c < 0.85:
            self.emit("csrr x%d, minstret" % self.xdst())
        elif c < 0.92:
            self.emit("csrrsi x%d, fflags, %d" % (self.xdst(), self.r.randint(0, 31)))
        else:
            self.emit("csrrci x%d, fflags, %d" % (self.xdst(), self.r.randint(0, 31)))

    def ctrl_op(self, body):
        c = self.r.random()
        self.label += 1
        lab = "L%d" % self.label
        if c < 0.5:
            self.emit("%s x%d, x%d, %s" % (self.r.choice(BRANCH), self.xsrc(), self.xsrc(), lab))
        elif c < 0.7:
            self.emit("jal x%d, %s" % (self.xdst(), lab))
        else:
            r = self.xdst()
            self.emit("la x%d, %s" % (r, lab))
            self.emit("jalr x%d, 0(x%d)" % (self.xdst(), r))
        for _ in range(self.r.randint(0, 3)):
            body()
        self.lines.append("%s:" % lab)

    def special_op(self):
        c = self.r.random()
        if c < 0.25:
            self.emit("ecall")
        elif c < 0.45:
            self.emit("ebreak")
        elif c < 0.65:
            self.emit(".word 0x%08x" % self.r.choice([0x00000000, 0xffffffff, 0xc0001073, 0x0000600b]))
        elif c < 0.8:
            self.emit("fence")
        else:
            self.emit("fence.i")

    def program(self, length):
        def body():
            c = self.r.random()
            if self.kind == "int":
                weights = [0.75, 0.0, 0.08, 0.12, 0.05]
            elif self.kind == "fp":
                weights = [0.25, 0.55, 0.1, 0.07, 0.03]
            else:
                weights = [0.45, 0.3, 0.1, 0.1, 0.05]
            acc = 0
            if not self.has_f:
                # F instructions trap: a tenth of the usual share (the CSR mix keeps its F CSRs)
                weights = [weights[0] + 0.9 * weights[1], 0.1 * weights[1]] + weights[2:]
            for w, f in zip(weights, [self.int_op, self.fp_op, self.csr_op, None, self.special_op]):
                acc += w
                if c < acc:
                    if f is None:
                        self.ctrl_op(body)
                    else:
                        f()
                    return
            self.int_op()

        for _ in range(length):
            body()


PROLOGUE = """    .section .text.init
    .globl _start
_start:
    la x30, trap
    csrw mtvec, x30
    li x30, 0x2000
    csrs mstatus, x30
    csrwi fcsr, 0
    csrw minstret, x0
    csrw minstreth, x0
    la x29, buffer
"""

TRAP = """
    .align 2
trap:
    csrr x30, mepc
    addi x30, x30, 4
    csrw mepc, x30
    csrr x31, mcause
    mret
"""

EPILOGUE = """
    fence
    li x30, 1
    la x31, tohost
    sw x30, 0(x31)
1:  j 1b
"""


def write_program(path, rnd, kind, length, isa="rv32imf"):
    g = Gen(rnd, kind, isa)
    init = []
    for r in XREGS:
        init.append("    li x%d, 0x%x" % (r, rnd.getrandbits(32) if rnd.random() < 0.7 else rnd.choice(SPECIAL_X) & 0xffffffff))
    for r in FREGS:
        init.append("    li x31, 0x%x" % (rnd.choice(SPECIAL_F) if rnd.random() < 0.4 else rnd.getrandbits(32)))
        init.append("    fmv.w.x f%d, x31" % r)
    g.program(length)
    data = ["    .word 0x%08x" % rnd.getrandbits(32) for _ in range(300)]
    with open(path, "w") as f:
        f.write(PROLOGUE + "\n".join(init) + "\n" + "\n".join(g.lines) + EPILOGUE + TRAP)
        f.write("\n    .section .tohost, \"aw\", @progbits\n    .align 6\n    .globl tohost\ntohost: .dword 0\n"
                "    .align 6\n    .globl fromhost\nfromhost: .dword 0\n")
        f.write("\n    .data\n    .align 4\nbuffer:\n" + "\n".join(data) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--count", type=int, default=100)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--kind", default="all", choices=["all", "int", "fp"])
    ap.add_argument("--length", type=int, default=400)
    ap.add_argument("--isa", default="rv32imf", choices=["rv32i", "rv32im", "rv32imf"])
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for i in range(a.count):
        rnd = random.Random(a.seed * 100003 + i)
        kinds = ["all", "int", "fp"] if "f" in a.isa[len("rv32i"):] else ["all", "int"]
        kind = a.kind if a.kind != "all" else kinds[i % len(kinds)]
        name = os.path.join(a.out, "rand_%d_%04d" % (a.seed, i))
        write_program(name + ".S", rnd, kind, a.length, a.isa)
        r = subprocess.run(["riscv32-unknown-elf-gcc", "-march=rv32imf_zicsr_zifencei", "-mabi=ilp32",
                            "-static", "-nostdlib", "-nostartfiles",
                            "-T", os.path.join(TESTS, "env", "p", "link.ld"), name + ".S", "-o", name + ".elf"],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if r.returncode:
            raise SystemExit("build failed for %s:\n%s" % (name, r.stdout))


if __name__ == "__main__":
    main()
