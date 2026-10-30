"""RISCV-DV (pygen) core setting for HORNET.

One file for every ISA configuration: HORNET_ISA (rv32i, rv32im, rv32imf)
selects the instruction groups the generator may use. scripts/dv/pygen_run.py
registers this module as pygen_src.target.<target>.riscv_core_setting, so the
riscv-dv submodule stays unmodified.
"""
import math
import os

from pygen_src.riscv_instr_pkg import (privileged_reg_t, satp_mode_t,
                                       riscv_instr_group_t, mtvec_mode_t,
                                       privileged_mode_t)

ISA = os.environ.get("HORNET_ISA", "rv32imf")
_EXT = ISA[len("rv32i"):]

XLEN = 32
SATP_MODE = satp_mode_t.BARE

# machine mode only (ADR-0006)
supported_privileged_mode = [privileged_mode_t.MACHINE_MODE]

unsupported_instr = []

supported_isa = [riscv_instr_group_t.RV32I]
if "m" in _EXT:
    supported_isa.append(riscv_instr_group_t.RV32M)
if "f" in _EXT:
    supported_isa.append(riscv_instr_group_t.RV32F)

supported_interrupt_mode = [mtvec_mode_t.DIRECT, mtvec_mode_t.VECTORED]
max_interrupt_vector_num = 32

support_pmp = 0
support_debug_mode = 0
support_umode_trap = 0
support_sfence = 0
# misaligned loads and stores trap (cause 4/6) instead of being split
support_unaligned_load_store = 0

NUM_FLOAT_GPR = 32
NUM_GPR = 32
NUM_VEC_GPR = 32
VECTOR_EXTENSION_ENABLE = 0
VLEN = 512
ELEN = 32
SELEN = 8
VELEN = int(math.log(ELEN) // math.log(2)) - 3
MAX_LMUL = 8
NUM_HARTS = 1

# machine-mode CSRs of HORNET that the generator may access (docs: CSRs)
implemented_csr = [privileged_reg_t.MVENDORID,
                   privileged_reg_t.MARCHID,
                   privileged_reg_t.MIMPID,
                   privileged_reg_t.MHARTID,
                   privileged_reg_t.MSTATUS,
                   privileged_reg_t.MISA,
                   privileged_reg_t.MIE,
                   privileged_reg_t.MTVEC,
                   privileged_reg_t.MSCRATCH,
                   privileged_reg_t.MEPC,
                   privileged_reg_t.MCAUSE,
                   privileged_reg_t.MTVAL,
                   privileged_reg_t.MIP]

custom_csr = []
