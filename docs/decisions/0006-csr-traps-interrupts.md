# ADR-0006: CSRs, traps and interrupts

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** `csr_unit`, decoder, `mem_stage`, `hazard_unit`, `hornet_core`
- **Follows:** the proposed path of PythaCore `docs/research/csr-traps.md` (§10 decisions)

## Context

The old CSR unit read CSRs in ID and wrote them in WB, stalled any
instruction whose CSR address matched one in flight, kept `fflags` as the
flags of the last FP instruction only (not accumulated), had no
`mtval`, counters or `misa`, took interrupts by flushing whichever stages
were not "dummy", and had an FSM that could miss interrupts during stalls.

## Decision

The research document's recommendations, with three HORNET-specific
additions (marked +):

| # | Item | Decision |
|---|---|---|
| 1 | Privilege | Machine mode only |
| 2 | Commit point | CSR reads/writes, traps, `mret` and counter updates commit when the instruction leaves **MEM** |
| 3 | Interrupt entry | tag the instruction in ID as an interrupt carrier; refetch after writes that change interrupt or FP state |
| 4 | `mtvec` | Direct and Vectored (+: the HORNET drivers use vectored mode); reset value a parameter |
| 5 | `mtval` | informative, as Spike |
| 6 | `mcause` | 32 bits |
| 7 | `time`/`timeh` | from the SoC timer (`mtime_i`) |
| 8 | Debug triggers | `tselect`, `tdata1..3` read zero |
| 9 | `WFI` | NOP |
| 10 | `misa` | read-only, `RV32IMF` |
| 11 | `mhartid`, `mimpid` | parameters, default 0 |
| 12 | Misaligned accesses | trap (cause 4/6); jump targets cause 0 |
| 13 | RVFI | as research §7 |
| 14 | Fast interrupts | + 16 lines in `mip/mie[31:16]` (HORNET has them; UART and GPIO use them) |
| 15 | F state | + `fflags`, `frm`, `fcsr` (accumulated flags, ADR-0007) and `mstatus.FS`/`SD`; F instructions are illegal while `FS = Off` |

- Exceptions are detected where their information is (fetch fault: IF,
  illegal/ecall/ebreak: ID, misaligned target: EX, misaligned access: MEM,
  access fault: WB), travel with the instruction and are taken at MEM
  (access faults at WB, which then also discards MEM).
- Refetch after a committing write to `mstatus`, `mie`, `frm`, `fcsr`.
- A CSR result is a late producer (one stall for a direct consumer).
- Interrupt priority: fast lines (31 down to 16), then MEI, MSI, MTI.

## Consequences

- `rv32mi` (except `pmpaddr`, `breakpoint` needs the read-zero triggers)
  against Spike with `--priv=m --pmpregions=0 --triggers=0`.
- riscv-formal CSR checks (`csrw`, `csr_ill`, `csrc_*`) for the integer CSRs.
- Directed interrupt tests in the SoC testbench.
