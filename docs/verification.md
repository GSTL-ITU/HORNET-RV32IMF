# Verification

HORNET is verified at four levels: the FPU alone, the core alone, the whole
SoC, and the FPGA build. Every method compares the design with an
independent reference: the RISC-V reference simulator Spike [[SPIKE]](references.md#verification-tools-and-suites),
the SoftFloat/TestFloat library [[TESTFLOAT]](references.md#arithmetic), the formal RISC-V model
of riscv-formal [[RV-FORMAL]](references.md#verification-tools-and-suites), or results measured on hardware. The
programs come from riscv-tests [[RV-TESTS]](references.md#verification-tools-and-suites), RISCV-DV [[RISCV-DV]](references.md#verification-tools-and-suites)
and HORNET's own generators; the simulator is Verilator [[VERILATOR]](references.md#verification-tools-and-suites). Everything runs in the `hornet-dev` Docker
image and is started from the top-level Makefile.

## Methods

| Method | Target | Reference | What it finds | Time |
|---|---|---|---|---|
| Lint | `make lint` | Verilog-2005 rules | width mismatches, unused or undriven signals, non-portable constructs | seconds |
| TestFloat vectors | `make fpu-test` | SoftFloat (TestFloat 3e) | wrong results and flags of every FP operation, all rounding modes | 3 min |
| Directed FPU vectors | `make fpu-test` | exact rational model (`fpu_directed.py`) | the corner cases where version 1 failed | (included) |
| riscv-tests co-simulation | `make cosim` | Spike | wrong behaviour of each instruction and of traps/CSRs | 1 min |
| … with random wait states | `make cosim-stall` | Spike | bugs in the memory handshake, stalls, response capture | 1 min |
| Random programs | `make random` | Spike | hazards between random instructions, FP corner values, traps | 3 min |
| RISCV-DV | `make riscv-dv` | Spike | the same with the industry-standard generator and test list | 15 min |
| Formal (riscv-formal) | `make formal` | riscv-formal ISA model | any integer-instruction or CSR bug reachable within the check depth, for all inputs | about 1 h |
| SoC test programs | `make sw-tests` | self-checking C | peripherals, interrupts, bus errors, AXI, FENCE.I, ISA configuration | 1 min |
| Bootloader | `make boot-test` | expected program output | the UART loading path | 1 min |
| Application | `make -C sw/examples/IDS-MLP-uart-fpga check` | results measured on the FPGA | a full floating-point application | 2 min |
| FPGA timing | `make fpga-build` | Vivado static timing | timing at the target clock | 5 min |

`make regress` runs lint, the FPU vectors, the co-simulations, the random
programs, the SoC tests, the bootloader test and formal for one ISA;
`make regress-isas` runs the simulation checks for all three
configurations; `make formal-isas` runs formal for all three.

## Results of this release

| Check | RV32I | RV32IM | RV32IMF |
|---|---|---|---|
| lint | clean | clean | clean |
| riscv-tests vs. Spike, plain and with 30 % random wait states | 56/56 | 64/64 | 75/75 |
| random programs vs. Spike, plain and with wait states | 200/200 | 200/200 | 200/200 |
| RISCV-DV programs and custom tests vs. Spike | 19/19 | 20/20 | 36/36 |
| SoC test programs | 5/5 | 5/5 | 6/6 |
| bootloader test | pass | pass | pass |

- **FPU** (the same unit in every configuration): 4 270 432 TestFloat
  vectors and 1 637 642 directed vectors, all five rounding modes, 0
  failures. Version 1 failed 3 560 239 of the TestFloat vectors.
- **riscv-formal:** 151/151 checks for RV32IMF.
- **Application:** the MLP example gives the classes measured on the FPGA.
- **FPGA:** timing met at 50 MHz on both boards; the MLP build with
  320 KB of IMEM runs at 41.7 MHz ([FPGA: results](fpga.md#results)).
- Two riscv-tests are skipped by design: `rv32ui-ma_data` (misaligned
  accesses trap on HORNET) and `rv32mi-pmpaddr` (no PMP).

All results were produced with the commands below, in the `hornet-dev`
image, on 2026-10-31 (formal: 2026-10-22):

```bash
make docker-build
make fpu-test
# lint, cosim, cosim-stall, random, sw-tests, boot-test for RV32I, RV32IM, RV32IMF
make regress-isas
for isa in rv32i rv32im rv32imf; do make riscv-dv ISA=$isa; done
make formal-isas           # about one hour per configuration
```

Logs and summaries are in `build/` ([Repository: build
directories](repository.md#build-directories)).

## Reporting a bug

Open an issue with the program (or a few instructions) that shows it and
how it was built; what was expected and what happened (UART output, `build/`
logs, a waveform from `+waves=<file>.fst`); and where it happened
(simulation, which board, a block design). A fix comes with a test that
fails without it, and `make regress` must still pass.
