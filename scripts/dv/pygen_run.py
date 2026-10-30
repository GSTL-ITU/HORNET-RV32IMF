#!/usr/bin/env python3
"""Runs a RISCV-DV pygen test with the HORNET core setting.

  pygen_run.py <riscv-dv dir> <target dir> <pygen test> [pygen options ...]

pygen imports its core setting as pygen_src.target.<target>.riscv_core_setting,
i.e. only targets inside the riscv-dv tree. This launcher registers the
package pygen_src.target.hornet with its path set to <target dir> (which
holds riscv_core_setting.py, verif/dv/), then runs
pygen/pygen_src/test/<pygen test>.py with the options as target "hornet",
so the submodule is used unmodified.

Fixes of pygen bugs, applied here at run time (the upstream code is not changed):

  1. pygen runs each program in a multiprocessing.Pool worker; when a
     constraint cannot be solved it calls sys.exit(1) inside the worker and the
     pool waits forever. The pool is replaced by a serial map in this process
     (the driver asks for one program per call), so such a failure ends the
     process with exit code 1 and the driver retries with another seed.
  2. riscv_instr.build_basic_instruction_list mixes instruction names (strings,
     "EBREAK", "WFI") with the enum keys of the instruction templates and
     appends whole categories (SYNCH, CSR) as single list elements: with
     +no_ebreak=0 every program fails with KeyError 'EBREAK', and picking a
     list element fails. The list is rebuilt from template keys.
  3. riscv_load_store_base_instr_stream has its base-register constraint
     commented out ("TODO Getting pyvsc error"): the base can be x0 (GCC rejects
     "la zero, region") or a reserved register (the trap handler's). The base
     is re-drawn from the free registers before the stream is built.
  4. The same stream collects the allowed load/store instructions over all
     addresses (allowed_instr is not cleared per address), so halfword and
     word accesses land on odd addresses, and the accesses do not keep the
     stream's base register. The test ends at the first such access (RISCV-DV's
     handler treats misaligned accesses as fatal). After the stream is built
     every access uses the base register and its offset is aligned to the
     access size.
  6. riscv_instr.get_load_store_instr returns a shallow copy (copy.copy) of the
     instruction template, so all loads/stores of one kind share their operand
     fields and the last stream that sets them wins: the accesses use another
     stream's base register (wild addresses, the test ends at the first access
     fault). It returns a deep copy, as get_rand_instr does.
  7. gen_ebreak_handler is a stub ("TODO") and the exception handler only
     dispatches ECALL and illegal instructions, so the first EBREAK ends the
     test. The handler is added (mepc += 4, as RISCV-DV's SystemVerilog
     generator does) and dispatched for cause 3.
  8. riscv_instr_sequence.insert_illegal_hint_instr fails the whole program
     when one of its illegal encodings cannot be solved (pyvsc solve failures
     happen at random), and does not tie the encoding's "compressed" bit to
     +disable_compressed_instr. Each encoding is retried, 32-bit only without C;
     one that has no solution in 50 attempts is left out (logged).
  5. randomize_gpr's constraints against the reserved registers (tp, sp, the
     handler's scratch register, the stream's own reserved destinations) do
     not take effect (pyvsc foreach over Python lists): random instructions
     overwrite tp and the base registers. A destination that is reserved is
     re-drawn after randomisation.
"""
import os
import copy
import logging
import multiprocessing
import random
import runpy
import sys
import types


class SerialPool:
    """multiprocessing.Pool stand-in: map in this process."""

    def __init__(self, *args, **kwargs):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def map(self, fn, items):
        return [fn(i) for i in items]


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    dv, target_dir, test = sys.argv[1:4]
    pygen = os.path.join(os.path.abspath(dv), "pygen")
    sys.path.insert(0, pygen)
    script = os.path.join(pygen, "pygen_src", "test", test + ".py")
    # pygen parses sys.argv when its configuration module is imported
    sys.argv = [script, "--target", "hornet"] + sys.argv[4:]

    import pygen_src.target  # noqa: F401  (the real package)
    pkg = types.ModuleType("pygen_src.target.hornet")
    pkg.__path__ = [os.path.abspath(target_dir)]
    sys.modules["pygen_src.target.hornet"] = pkg

    multiprocessing.Pool = SerialPool
    patch_pygen()
    runpy.run_path(script, run_name="__main__")


def patch_pygen():
    from pygen_src.riscv_instr_pkg import riscv_reg_t, riscv_instr_name_t
    from pygen_src.riscv_instr_gen_config import cfg
    from pygen_src.isa.riscv_instr import riscv_instr
    from pygen_src import riscv_load_store_instr_lib as ls

    # 2. the basic instruction list from template keys
    def build_basic_instruction_list(cls, cfg):
        basic = []
        for cat in ["SHIFT", "ARITHMETIC", "LOGICAL", "COMPARE"]:
            basic += cls.instr_category[cat]
        if cfg.no_ebreak == 0:
            basic.append(riscv_instr_name_t.EBREAK)
        if cfg.no_dret == 0:
            basic.append(riscv_instr_name_t.DRET)
        if cfg.no_fence == 0:
            basic += cls.instr_category["SYNCH"]
        if cfg.no_csr_instr == 0 and cfg.init_privileged_mode == "MACHINE_MODE":
            basic += cls.instr_category["CSR"]
        if cfg.no_wfi == 0:
            basic.append(riscv_instr_name_t.WFI)
        cls.basic_instr = [n for n in basic if n in cls.instr_template]
    riscv_instr.build_basic_instruction_list = classmethod(build_basic_instruction_list)

    from pygen_src.riscv_instr_stream import riscv_rand_instr_stream

    def reserved(stream):
        return {riscv_reg_t(int(r)) for r in list(cfg.reserved_regs) + list(stream.reserved_rd)}

    # 3. a free base register for the load/store streams, 4. accesses on it, aligned
    orig_post = ls.riscv_load_store_base_instr_stream.post_randomize
    size = {"LB": 1, "LBU": 1, "SB": 1, "LH": 2, "LHU": 2, "SH": 2, "LW": 4, "SW": 4, "FLW": 4, "FSW": 4}

    def post_randomize(self):
        bad = {riscv_reg_t.ZERO} | reserved(self)
        if riscv_reg_t(int(self.rs1_reg)) in bad:
            self.rs1_reg = random.choice([r for r in riscv_reg_t if r not in bad])
        orig_post(self)
        for instr in self.load_store_instr:
            instr.rs1 = self.rs1_reg
            n = size.get(instr.instr_name.name, 1)
            off = int(instr.imm_str)
            off -= (self.base + off) % n
            if off < -2048:
                off += n
            instr.imm_str = str(off)
    ls.riscv_load_store_base_instr_stream.post_randomize = post_randomize

    # 5. reserved destinations
    orig_gpr = riscv_rand_instr_stream.randomize_gpr

    def randomize_gpr(self, instr):
        instr = orig_gpr(self, instr)
        bad = reserved(self)
        if instr.has_rd and riscv_reg_t(int(instr.rd)) in bad:
            instr.rd = random.choice([r for r in riscv_reg_t if r not in bad])
        return instr
    riscv_rand_instr_stream.randomize_gpr = randomize_gpr

    # 6. load/store instructions as deep copies
    def get_load_store_instr(cls, load_store_instr):
        if len(load_store_instr) == 0:
            load_store_instr = cls.instr_category["LOAD"] + cls.instr_category["STORE"]
        return copy.deepcopy(cls.instr_template[random.choice(load_store_instr)])
    riscv_instr.get_load_store_instr = classmethod(get_load_store_instr)

    # 7. EBREAK handler
    from pygen_src.riscv_asm_program_gen import riscv_asm_program_gen
    from pygen_src.riscv_instr_pkg import pkg_ins, privileged_reg_t
    orig_section = riscv_asm_program_gen.gen_section

    def gen_section(self, label, instr):
        if label.endswith("mode_exception_handler"):
            at = next(i for i, l in enumerate(instr) if "# MTVAL" in l)
            instr[at:at] = ["li x%d, 0x3 # BREAKPOINT" % cfg.gpr[1],
                            "beq x%d, x%d, %s" % (cfg.gpr[0], cfg.gpr[1],
                                                  label.replace("mmode_exception_handler", "ebreak_handler"))]
        return orig_section(self, label, instr)
    riscv_asm_program_gen.gen_section = gen_section

    def gen_ebreak_handler(self, hart):
        instr = ["csrr  x%d, %s" % (cfg.gpr[0], hex(privileged_reg_t.MEPC)),
                 "addi  x%d, x%d, 4" % (cfg.gpr[0], cfg.gpr[0]),
                 "csrw  %s, x%d" % (hex(privileged_reg_t.MEPC), cfg.gpr[0])]
        pkg_ins.pop_gpr_from_kernel_stack(privileged_reg_t.MSTATUS, privileged_reg_t.MSCRATCH,
                                          cfg.mstatus_mprv, cfg.sp, cfg.tp, instr)
        instr.append("mret")
        orig_section(self, pkg_ins.get_label("ebreak_handler", hart), instr)
    riscv_asm_program_gen.gen_ebreak_handler = gen_ebreak_handler

    # 8. illegal encodings with retries, 32-bit without C
    import vsc
    from vsc.model.solve_failure import SolveFailure
    from pygen_src.riscv_instr_sequence import riscv_instr_sequence
    from pygen_src.riscv_illegal_instr import illegal_instr_type_e

    def solve(ill, hint):
        for _ in range(50):
            try:
                with vsc.randomize_with(ill):
                    if hint:
                        ill.exception == illegal_instr_type_e.kHintInstr
                    else:
                        ill.exception != illegal_instr_type_e.kHintInstr
                    if cfg.disable_compressed_instr:
                        ill.compressed == 0
                return True
            except SolveFailure:
                continue
        logging.warning("illegal/HINT encoding: no solution in 50 attempts, left out")
        return False

    def insert_illegal_hint_instr(self):
        self.illegal_instr.initialize()
        for ratio, hint, directive in ((cfg.illegal_instr_ratio, False, ".4byte"), (cfg.hint_instr_ratio, True, ".2byte")):
            for _ in range(int(self.instr_cnt * ratio / 1000)):
                if not solve(self.illegal_instr, hint):
                    continue
                text = "{}{} {} # {}".format(pkg_ins.indent, directive, self.illegal_instr.get_bin_str(),
                                             self.illegal_instr.comment)
                self.instr_string_list.insert(random.randrange(0, len(self.instr_string_list)), text)
    riscv_instr_sequence.insert_illegal_hint_instr = insert_illegal_hint_instr


if __name__ == "__main__":
    main()
