# ADR-0009: RVFI and formal verification

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** `hornet_core`, `verif/formal/`
- **Follows:** PythaCore ADR-0005 and research §7

## Decision

- One retirement channel, flat `rvfi_*` outputs, always present, driven
  from the MEM/WB register; fields as PythaCore ADR-0005 with the trap
  extensions of research §7 (`rvfi_trap` for every exception, `pc_wdata`
  of a trapping instruction is the handler address, `rvfi_intr` on the
  first handler instruction of an interrupt, CSR ports for the checked
  CSRs).
- Float register writes are reported on extra, non-RVFI outputs
  (`rvfi_frd_addr`, `rvfi_frd_wdata`, `rvfi_fflags`) for the co-simulation;
  `rvfi_rd_addr` stays 0 for them, so riscv-formal sees no write.
- riscv-formal with `isa rv32im`, ALTOPS, the CSR checks; the FPU is a
  black box to formal.
