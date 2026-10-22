# ADR-0003: Core memory ports

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** `hornet_core`, `if_stage`, `mem_stage`, `wb_stage`, `lsu`
- **Follows:** PythaCore ADR-0004 (byte enables, LSU in the core) and ADR-0008 (request/grant/valid)

## Context

The old core drove the instruction address combinationally from the next-PC
mux, issued data requests from EX, split misaligned accesses into two bus
cycles in hardware, and spoke Wishbone with a stall signal whose timing
differed between the two ports.

## Decision

PythaCore's port definition, plus an error bit on each response:

```verilog
// instruction port
output        instr_req_o,    input instr_gnt_i,
output [31:0] instr_addr_o,   // word-aligned
input         instr_rvalid_i, input [31:0] instr_rdata_i, input instr_err_i,
// data port
output        data_req_o,     input data_gnt_i,
output        data_we_o,
output [3:0]  data_be_o,      // lane-shifted, loads and stores
output [31:0] data_addr_o,    // word-aligned
output [31:0] data_wdata_o,   // lane-shifted
input         data_rvalid_i,  input [31:0] data_rdata_i, input data_err_i
```

The protocol rules of PythaCore ADR-0008 apply: a raised request stays
stable until granted, one response per accepted request, in order, at
least one cycle later, at most one request outstanding per port. IF is a
fetch unit with a one-entry buffer; MEM issues; WB receives, aligns and
extends load data; a waiting MEM or WB holds the whole pipeline.

- `instr_err_i` marks the fetched instruction with an instruction access
  fault (cause 1).
- `data_err_i` raises a load or store access fault (cause 5 or 7) in WB;
  in that cycle nothing in MEM commits (ADR-0006).
- Misaligned loads and stores are not split; they trap (ADR-0006).

## Consequences

- The SoC (ADR-0002, ADR-0008) and the testbench memory both implement the
  port; the testbench inserts random wait states (`+mem_stall=<pct>`).
