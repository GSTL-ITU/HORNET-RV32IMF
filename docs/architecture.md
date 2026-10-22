# HORNET architecture

## SoC

```
                 +-------------------------------- hornet_soc ---------------------------------+
                 |                                                                             |
                 |   +----------- hornet_core -----------+        instruction port             |
                 |   |                                   |---------------------------+         |
                 |   |  IF -> ID -> EX -> MEM -> WB      |                           v         |
                 |   |        |     |      |             |                   +-------------+   |
                 |   |    regfile  ALU    MUL   CSR unit  |                   | IMEM (BRAM) |   |
                 |   |   (x + f)   DIV    LSU            |                   | port A: I   |   |
                 |   |            FPU                     |  data port       | port B: D   |   |
                 |   +-----------------------------------+--------+         +-------------+   |
                 |                                                 |                ^         |
                 |                                          +-------------+         |         |
                 |                                          | data_router |---------+         |
                 |                                          +-------------+--------------+    |
                 |                                                 |                     v    |
                 |                                      +-----------------+      +-------------+
                 |                                      | obi_axil_bridge |      | DMEM (BRAM) |
                 |                                      +-----------------+      +-------------+
                 |                                                 | AXI4-Lite                 |
                 |                                          +------------+                     |
                 |                                          | axil_xbar  |---- DECERR for holes|
                 |                                          +------------+                     |
                 |              +-----------+-----------+-----------+-----------+              |
                 |              |           |           |           |           |              |
                 |           timer        UART        GPIO      sysctl      external ---------- m_axi_* (Vivado IP)
                 |         (CLINT)                                                             |
                 +-----------|-----------|-----------|-------------------------------------------+
                          mtip,msip   uart pins   gpio pins, irq
```

- **Harvard memory** ([ADR-0002](decisions/0002-memory-system.md)): the
  instruction port reaches only IMEM; the data port reaches DMEM, IMEM (port B,
  for `.rodata` and the bootloader) and the AXI4-Lite bus. Both memories are
  synchronous block RAMs that answer one cycle after a request. No caches.
- **Bus** ([ADR-0008](decisions/0008-axi4-lite-bus.md)): the core's
  request/grant/valid data port goes through `data_router`; peripheral
  accesses are converted to AXI4-Lite by `obi_axil_bridge` and decoded by
  `axil_xbar`. Unmapped addresses and `SLVERR`/`DECERR` answers raise access
  faults.

### Memory map

| Address | Size | Block |
|---|---|---|
| `0x0000_0000` | 64 KB (parameter) | IMEM |
| `0x1000_0000` | 64 KB (parameter) | DMEM |
| `0x2000_0000` | 64 KB | timer (CLINT layout) |
| `0x2001_0000` | 64 KB | UART |
| `0x2002_0000` | 64 KB | GPIO |
| `0x2003_0000` | 64 KB | system control |
| `0x4000_0000` | 1 GB | external AXI4-Lite port |

Register maps: [peripherals.md](peripherals.md).

### Interrupts

| Source | `mip` bit | `mcause` |
|---|---|---|
| timer `msip` | 3 (MSI) | `0x8000_0003` |
| timer `mtime >= mtimecmp` | 7 (MTI) | `0x8000_0007` |
| pin `meip_i` | 11 (MEI) | `0x8000_000B` |
| UART | 16 | `0x8000_0010` |
| GPIO | 17 | `0x8000_0011` |
| pins `irq_i[13:0]` | 18..31 | `0x8000_0012`..`0x8000_001F` |

Priority: fast lines from 31 down to 16, then MEI, MSI, MTI. In vectored mode
an interrupt with cause *n* jumps to `mtvec.BASE + 4n`.

## Core pipeline

```
 IF            ID                 EX                       MEM                    WB
 fetch unit -> decode,          -> forwarding muxes      -> data request        -> data response
 (PC, req,     register read,      ALU, branch/JALR         misaligned check       load align/extend
 1-entry       immediate,          divider (iterative)      multiplier             access faults
 buffer)       JAL redirect,       FPU (single- and         CSR read/write         register write
               interrupt tag       multi-cycle)             trap, mret, refetch    RVFI
```

| Topic | Behaviour |
|---|---|
| Branches, JALR | resolved in EX, predict not taken: 2 bubbles when taken |
| JAL | resolved in ID: 1 bubble |
| Forwarding | into EX from MEM and WB, integer and float registers in one namespace |
| Late producers | loads, multiplies, CSR reads: one stall for a directly dependent instruction |
| Divider | 34 cycles in EX (1 for division by zero and overflow); younger instructions wait, older ones drain |
| FPU | single-cycle in EX: sign injection, min/max, compare, classify, moves; multi-cycle: FMA (6 cycles), divide/square root (up to 29), conversions (3) |
| Memory waits | a waiting MEM or WB holds the whole pipeline |
| Traps | precise; detected where the information is (fetch fault IF, illegal/ecall/ebreak ID, misaligned jump EX, misaligned access MEM, bus error WB) and taken when the instruction leaves MEM (WB for bus errors) |
| CSR writes | commit in MEM; writes to `mstatus`, `mie`, `frm`, `fcsr` and FENCE.I refetch the next instruction |
| Interrupts | the instruction in ID becomes a carrier that traps in MEM with `mepc` = its PC |

Measured CPI with block-RAM timing: 1.19 on rv32ui, 1.48 on rv32um, 1.38 on
rv32uf (riscv-tests, including their trap handling code).

### Files

| File | Block |
|---|---|
| `rtl/core/hornet_core.v` | top of the core, the wiring of the stages |
| `rtl/core/if_stage.v` | fetch unit and IF/ID |
| `rtl/core/id_stage.v`, `control_unit.v`, `imm_decoder.v`, `regfile.v` | decode, JAL, interrupt tagging, register files, ID/EX |
| `rtl/core/ex_stage.v`, `ALU.v`, `div.v` | EX and EX/MEM |
| `rtl/core/mem_stage.v`, `mul.v` | MEM and MEM/WB |
| `rtl/core/wb_stage.v` | WB and RVFI |
| `rtl/core/hazard_unit.v` | stalls, flushes, redirects, forwarding selects |
| `rtl/core/csr_unit.v` | CSRs, trap entry, `mret`, counters, interrupt pending |
| `rtl/fpu/fpu_top.v` | FPU top: single-cycle operations, unit selection |
| `rtl/fpu/fpu_fma.v`, `fpu_divsqrt.v`, `fpu_cvt.v`, `fpu_round.v` | multi-cycle units and the shared rounding |
| `rtl/fpu/fpu_decoder.v`, `fpu_sign_inj.v`, `fpu_min_max.v`, `fpu_compare.v`, `fpu_classifier.v` | from version 1, unchanged |

## CSRs

Machine mode only ([ADR-0006](decisions/0006-csr-traps-interrupts.md)).

| CSRs | Notes |
|---|---|
| `mstatus` | MIE, MPIE, FS (Off at reset; `crt0` turns it on), MPP = M, SD |
| `misa` | `0x4000_1120` (RV32IMF), read only |
| `mie`, `mip` | bits 3, 7, 11 and 16..31 |
| `mtvec` | direct and vectored |
| `mscratch`, `mepc`, `mcause`, `mtval` | `mtval` holds the instruction, address or target as Spike does |
| `mcycle[h]`, `minstret[h]`, `mcountinhibit` | 64-bit counters; user aliases `cycle`, `instret` |
| `time[h]` | read only, `mtime` of the timer |
| `fflags`, `frm`, `fcsr` | illegal while `mstatus.FS` is Off |
| `mvendorid`, `marchid`, `mimpid`, `mhartid`, `mconfigptr`, `mstatush` | read as 0 (`mhartid` parameter) |
| `mhpmcounter3..31`, `mhpmevent3..31`, `tselect`, `tdata1..3` | read as 0, writes ignored |

Every other CSR address raises an illegal-instruction exception.

## Clock and resources

On the Nexys 4 DDR (Artix-7 100T, Vivado 2025.2), with 64 KB IMEM and 64 KB DMEM:

| | |
|---|---|
| Clock | 50 MHz, worst slack 0.85 ns |
| LUTs / FFs | 6.6 k / 2.8 k (core 6.0 k / 2.0 k, of which EX with the FPU 4.0 k / 1.1 k) |
| DSP48 | 6 (multiplier and FMA) |
| BRAM36 | 32 |

The critical path is a load result forwarded into a branch comparison whose
redirect target is sent to the instruction memory in the same cycle (the
PythaCore ADR-0008 fetch scheme, which saves one cycle per taken branch).
Registering the redirect would allow a higher clock for one more cycle per
taken branch; that would be a new ADR. More block RAM (the 320 KB IMEM of the
MLP example) spreads over the device and needs a slower clock, see
[fpga.md](fpga.md).
