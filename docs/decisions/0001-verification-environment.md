# ADR-0001: Verification environment

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** `docker/`, `Makefile`, `tb/`, `scripts/`, `verif/`
- **Follows:** PythaCore ADR-0001 and its test flow

## Context

The old HORNET flow was a Vivado project, a simulation testbench that
watched a debug register, and RISCV-DV runs that are not in the repository.
Nothing could be rerun from a fresh clone, and the RTL was edited without a
regression to catch what broke.

## Decision

- One Docker image (`docker/Dockerfile`) with pinned versions of Verilator,
  the RISC-V GCC (`rv32imf/ilp32f` multilib), Spike, SoftFloat/TestFloat
  and the OSS CAD Suite (Yosys, SymbiYosys, solvers). `make` wraps every
  tool call in `docker run` on the host and calls the tools directly inside
  the container. Vivado stays on the host.
- **Co-simulation against Spike.** The testbench prints one line per
  retired instruction from RVFI (ADR-0009). `scripts/run_tests.py` runs the
  same ELF on Spike with `--log-commits` and compares PC, instruction,
  register writes (integer and float) and stores.
- **Suites:** riscv-tests `rv32ui`, `rv32um`, `rv32uf`, `rv32mi` with the
  standard `env/p` environment (tests end through `tohost`), plain and with
  random memory wait states; random instruction streams vs. Spike;
  TestFloat vectors for every FPU operation and rounding mode (ADR-0007);
  riscv-formal on RVFI (ADR-0009); C programs on the full SoC.
- Programs for the core testbench start at `0x8000_0000` (Spike's default);
  the testbench memory decodes the low address bits only.

## Consequences

- `make regress` is the gate before every commit that touches `rtl/`.
- Results and logs land in `build/`; the verification README records the
  numbers of each release.
