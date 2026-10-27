# HORNET verification

Everything runs in the `hornet-dev` Docker image
([ADR-0001](../decisions/0001-verification-environment.md)) and is started
from the top-level Makefile. `make regress` runs the gate checks; the SoC
and FPGA checks are separate targets.

| Target | What | Time |
|---|---|---|
| `make lint` | Verilator `-Wall` on the core and the SoC, as Verilog-2005 | seconds |
| `make fpu-test` | FPU alone against TestFloat vectors and the directed vectors for the RISCV-DV paper bugs | 3 min |
| `make cosim` | riscv-tests rv32ui/um/uf/mi, every retired instruction compared with Spike | 1 min |
| `make cosim-stall` | the same with 30 % random grant and response delays on both ports | 2 min |
| `make random` | random RV32IMF programs vs. Spike, plain and with wait states | 3 min |
| `make formal` | riscv-formal on the RVFI port | about 1 hour |
| `make sw-tests` | C test programs on the full SoC | 1 min |
| `make boot-test` | the UART bootloader loads and runs a program | 1 min |
| `make -C sw/examples/IDS-MLP-uart-fpga check` | MLP inference in simulation vs. the FPGA results | 2 min |
| `make fpga-build` | Vivado implementation and timing | 5 min |
| `make regress` | lint, fpu-test, cosim, cosim-stall, random, formal | |

Logs and summaries are written to `build/` (`build/tests/summary.txt`,
`build/formal/cores/hornet/summary.txt`, `build/sw-tests/summary.txt`, per-test logs next
to each program).

## Co-simulation against Spike

`tb/hornet_tb.sv` runs the core with a 4 MB memory model behind both
request/grant/valid ports. It writes one line per retired instruction from
RVFI in Spike's commit-log format (PC, instruction, integer and float register
writes, load and store addresses, store data) and checks RVFI consistency on
the fly (order counter, PC chain, `x0`). `scripts/run_tests.py` builds each
program, runs it on the RTL and on Spike
(`--isa=rv32imf_zicsr_zifencei_zicntr --priv=m --pmpregions=0 --triggers=0 --wfi-as-nop`)
and compares the traces. Reads of `cycle`, `time`, `mcycle` and `marchid` are
masked; trapping instructions, which Spike does not log, are dropped.

With `+mem_stall=30` the memory model withholds grants and delays responses
(0-3 cycles) at random; this exercises the fetch buffer, the pipeline hold and
the response capture in WB.

| Suite | Tests | Result | Result, 30 % wait states |
|---|---|---|---|
| rv32ui | 41 | pass (`ma_data` skipped: misaligned accesses trap) | pass |
| rv32um | 8 | pass | pass |
| rv32uf | 11 | pass | pass |
| rv32mi | 15 | pass (`pmpaddr` skipped: no PMP) | pass |
| **total** | **75** | **75/75** | **75/75** |

CPI with zero wait states: rv32ui 1.19, rv32um 1.48, rv32uf 1.38.

## Random programs

`scripts/gen_random.py` writes programs of 400 random instructions after a
prologue that randomises all registers (with NaN, infinity, subnormal and
boundary values). Sources are biased towards the last three destinations, so
most instructions depend on one at distance 1-3. The mix contains ALU, loads
and stores (some misaligned), M instructions with division corner cases, every
F instruction in static and dynamic rounding modes, CSR traffic on `fflags`,
`frm` (also invalid values), `fcsr`, `mscratch`, `minstret`, branches, JAL,
JALR, ECALL, EBREAK, illegal words, FENCE and FENCE.I. A small trap handler
skips trapping instructions and reads `mcause`.

| Run | Programs | Instructions | Traps | Result |
|---|---|---|---|---|
| `make random RANDOM=200` (seed 1) | 200 | 136 186 | 3 074 | pass |
| the same with 30 % wait states | 200 | 136 186 | 3 074 | pass |

## FPU

`tb/fpu_tb.sv` drives `fpu_top` alone. `scripts/fpu_vectors.py` takes the
vectors from TestFloat 3e (RISC-V specialisation, tininess after rounding, all
five rounding modes): `f32_add`, `f32_sub`, `f32_mul`, `f32_div`, `f32_sqrt`,
`f32_to_i32`, `f32_to_ui32`, `i32_to_f32`, `ui32_to_f32`, `f32_eq`, `f32_lt`,
`f32_le` at level 1, and every 40th case of `f32_mulAdd` (6.1 M cases per
rounding mode) for FMADD and, with negated operands, FMSUB, FNMSUB and FNMADD.
Min/max, sign injection and classify come from a reference model in the
script (special values and 20 000 random pairs). Result and flags must match
bit for bit.

| Operation | Vectors | Version 2 | Version 1 (values only) | Version 1 (values and flags) |
|---|---|---|---|---|
| FADD | 232 320 | 0 failures | 102 | 98 571 |
| FSUB | 232 320 | 0 | 103 | 98 608 |
| FMUL | 232 320 | 0 | 128 | 114 191 |
| FMADD, FMSUB, FNMSUB, FNMADD | 4 × 766 660 | 0 | not implemented | not implemented |
| FDIV | 232 320 | 0 | 58 | 176 248 |
| FSQRT | 3 000 | 0 | 0 | 788 |
| FCVT.W.S, FCVT.WU.S | 2 × 3 000 | 0 | 2, 1 | 2 595, 2 780 |
| FCVT.S.W, FCVT.S.WU | 2 × 1 860 | 0 | 0 | 380, 730 |
| FEQ, FLT, FLE | 3 × 46 464 | 0 | 0 | 0 |
| FMIN, FMAX, FSGNJ[N/X], FCLASS | 6 × 20 400 | 0 | 0 | 0 |
| **total** | **4 270 432** | **0** | | **3 560 239** |

The version 1 column was measured with the same vectors through an adapter
to its `fpu_arithmetic_top`; its classify, sign injection, min/max and
compare modules pass and are kept in version 2.

### Directed vectors for the RISCV-DV paper bugs

The RISCV-DV paper (*Creating a Verification Environment Using
RISCV-DV With Open and Closed Source Tools*, section IV) lists the FPU bugs
that environment found: the dynamic rounding mode hardwired, wrong guard,
round and sticky bits in RTZ, RDN and RUP (its example
`0x4BB84A00 - 0x3F800001`, 24155136 - 1.0000001), rounding at overflow,
underflow and in conversions near ±∞, and lost precision in division and
square root of subnormals. `scripts/fpu_directed.py` (also run by
`make fpu-test`) writes vectors for each of these classes in all five
rounding modes. Expected values come from an exact rational model of
binary32 in the script, which first checks itself against TestFloat
(845 340 cases).

| Group | Vectors | Failures |
|---|---|---|
| `paper`: equation (2), its mirrored forms, the same pattern at every exponent | 27 610 | 0 |
| `grs`: addend at the guard, round and sticky positions, near cancellation | 199 997 | 0 |
| `tiny`: subnormal and smallest-normal operands and results | 300 000 | 0 |
| `ovf`: results around the largest finite value and the bottom of the subnormal range | 400 000 | 0 |
| `div`: subnormal dividends and divisors | 401 365 | 0 |
| `sqrt`: subnormal inputs (every exponent position, random and boundary mantissas) and normals | 300 460 | 0 |
| `cvt`: FCVT.W[U].S around 0, ±2^31, 2^32, ±∞ and NaN | 8 210 | 0 |
| **total** | **1 637 642** | **0** |

The paper's example in every mode (the faulty FPU returned `0x4BB84A00`
where it should round down):

| rm | RNE | RTZ | RDN | RUP | RMM |
|---|---|---|---|---|---|
| result (NX set) | `0x4BB849FF` | `0x4BB849FF` | `0x4BB849FF` | `0x4BB84A00` | `0x4BB849FF` |

`sw/tests/fpu` runs the same subtraction on the SoC with the dynamic rounding
mode (`frm` = 0 to 4) and with each static `rm` field.

## Formal (riscv-formal)

`verif/formal/` holds the wrapper and `checks.cfg`; `scripts/run_formal.sh`
generates and runs the checks with SymbiYosys (Boolector). Configuration:
`isa rv32im`, `csr_spec 1.12`, `RISCV_FORMAL_ALTOPS` (the multiplier and
divider compute riscv-formal's alternative results, the divider runs 3 steps,
the FPU is a stand-in with the real handshake,
[ADR-0009](../decisions/0009-rvfi-formal.md)). The wrapper leaves grants,
response timing, instruction and load data, the interrupt lines and `mtime`
free, and asserts the core's side of the port protocol (stable requests, one
outstanding request per port).

| Check group | Checks | Result |
|---|---|---|
| instruction checks (`insn_*`, RV32IM) | 45 | pass |
| `reg`, `pc_fwd`, `pc_bwd`, `unique`, `causal`, `ill` | 6 | pass |
| CSR semantics `csrw_*` (every CSR of `csr_spec 1.12` plus `mcountinhibit`) | 76 | pass |
| illegal CSRs `csr_ill_*` (S/U/H-mode CSRs, debug, PMP, `hpmcounter3`, ...) | 14 | pass |
| `csrc_const` (ID CSRs), `csrc_zero` (reserved bits of `mstatus`, `misa`, `mstatush`), `csrc_any` (`mscratch`) | 9 | pass |
| **total** | **151** | **151/151** (2026-10-22, 4 parallel jobs, about 70 minutes; `pc_fwd` alone about 35) |
| `cover` | 1 | pass |

The counter checks `csrc_inc`/`csrc_upcnt` are filtered (see the comment in
`checks.cfg`): they assume a core that retires every cycle and no
`mcountinhibit`. `minstret` is compared exactly with Spike instead.

Bugs found by formal and not by simulation:

| Bug | Check | Fix |
|---|---|---|
| `mepc` had no reset; MRET before the first write could jump to a PC with bit 1 set | `insn_beq`, `insn_jal` (misaligned PC after MRET) | `mepc[1:0]` read as zero ([commit](../../rtl/core/csr_unit.v)) |

## SoC programs

`tb/soc_tb.sv` runs `hornet_soc` with the program images. It decodes the UART
output, sends a file into the UART receiver (optionally in request/answer
blocks), attaches a 4 KB AXI4-Lite RAM with random ready delays to the
external port (`SLVERR` outside it) and loops GPIO outputs back to the inputs,
the fast interrupt pins and the external interrupt.

| Program | Checks | Result |
|---|---|---|
| `sw/tests/hello` | `printf`, FMA from C | pass |
| `sw/tests/irq` | direct-mode ECALL and illegal instruction; vectored timer, software, GPIO, fast-pin, external and UART RX interrupts | pass |
| `sw/tests/axi` | external AXI4-Lite RAM (word, half, byte); store/load access faults from `SLVERR`, `DECERR` and an unmapped address; misaligned load; `mcause` and `mtval` | pass |
| `sw/tests/fpu` | bit-exact results, accumulated `fflags`, `frm` | pass |
| `sw/tests/fencei` | code written into IMEM through the data port runs after FENCE.I | pass |
| `make boot-test` | bootloader alone in IMEM receives `hello.elf` over the UART and runs it | pass |
| MLP example (`make check`) | six NSL-KDD samples over the UART give the classes measured on the FPGA (0 0 4 1 4 4) | pass |
| `sw/examples/bubble_sort_float`, `fpu_filter` | `make sim` | pass |
