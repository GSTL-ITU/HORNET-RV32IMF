# Reference

## Parameters

### `hornet_core`

| Parameter | Default | Meaning |
|---|---|---|
| `RESET_VECTOR` | `0x0000_0000` | first PC after reset |
| `MTVEC_RESET` | `0x0000_0000` | `mtvec` after reset |
| `HART_ID` | 0 | `mhartid` |
| `RV_M` | 1 | M extension |
| `RV_F` | 1 | F extension |

### `hornet_soc`

`IMEM_SIZE`, `DMEM_SIZE`, `IMEM_INIT`, `DMEM_INIT`, `CLK_FREQ`, `BAUD`,
`BOOT_ADDR`, `RV_M`, `RV_F`: see [SoC: parameters](soc.md#parameters).

### `hornet_board`

The `hornet_soc` parameters (with `CLK_FREQ` derived from `CLK_DIV`), plus
`CLK_DIV` (default 20: 1000 MHz / 20 = 50 MHz), `N_LED` and `N_SW` (LED and
switch counts, at most 16).

## Make targets

| Target | Purpose | Main options |
|---|---|---|
| `docker-build`, `docker-build-ci`, `shell`, `tool-versions` | tool image; the smaller image of the GitHub workflows | `JOBS` |
| `lint` | Verilator lint | `ISA` |
| `sim`, `test` | build the core testbench; riscv-tests without Spike | `ISA`, `SUITES`, `TEST_ARGS` |
| `cosim`, `cosim-stall` | riscv-tests vs. Spike, without/with random wait states | `ISA`, `SUITES`, `MEM_STALL` |
| `random` | random programs vs. Spike, plain and with wait states | `ISA`, `RANDOM`, `SEED`, `MEM_STALL` |
| `riscv-dv`, `riscv-dv-loop` | RISCV-DV | `ISA`, `DV_TESTS`, `DV_ITER`, `DV_SEED`, `DV_RUNS`, `DV_ARGS` |
| `fpu-test` | FPU vectors | |
| `formal`, `formal-isas` | riscv-formal | `ISA`, `FORMAL_JOBS`, `FORMAL_TIMEOUT`, `FORMAL_CHECKS` |
| `soc-sim`, `sw-tests`, `boot-test` | SoC simulation | `ISA`, `HEX`, `SOC_ARGS`, `IMEM_SIZE`, `DMEM_SIZE`, `BOOT_ADDR` |
| `regress`, `regress-isas` | regression gates | `ISA`, `ISAS` |
| `coverage`, `coverage-isas` | code coverage of the simulation checks | `ISA`, `ISAS`, `COV_STEPS`; `COVERAGE=1` for any simulation target |
| `fpga-build`, `fpga-program`, `fpga-project`, `fpga-run` | Vivado flows | `BOARD`, `FPGA_PROG`, `BOOTLOADER`, `CLK_DIV`, `ISA`, `FPGA_BIT`, `ELF`, `PORT`, `LOG` |
| `fpga-ip`, `fpga-bd`, `fpga-default` | IP, block-design demo, default images | `BD_PROG` |
| `docs`, `docs-html`, `docs-figures` | the manuals | |
| `clean` | remove `build/` | |

Common options: `JOBS` (parallel jobs, 4), `MEMLIM` (container memory,
`8g`), `IMAGE` (`hornet-dev:latest`), `BUILD` (`build`).

## RTL file index

| File | Module | Chapter |
|---|---|---|
| `rtl/core/hornet_core.v` | core top | [Core](core.md) |
| `rtl/core/hornet_defs.vh` | opcodes, ALU and FPU codes, cause codes, CSR addresses | — |
| `rtl/core/if_stage.v` | fetch unit, IF/ID | [Core](core.md) |
| `rtl/core/id_stage.v`, `control_unit.v`, `imm_decoder.v`, `regfile.v` | decode, ID/EX, register files | [Core](core.md) |
| `rtl/core/ex_stage.v`, `ALU.v`, `div.v` | execute, EX/MEM | [Core](core.md) |
| `rtl/core/mem_stage.v`, `mul.v` | memory access, commit, MEM/WB | [Core](core.md) |
| `rtl/core/wb_stage.v` | write-back, RVFI | [Core](core.md) |
| `rtl/core/hazard_unit.v` | stalls, flushes, redirects, forwarding | [Core](core.md#latencies-and-penalties) |
| `rtl/core/csr_unit.v` | CSRs, traps, interrupts | [Programmer's model](programming.md) |
| `rtl/fpu/fpu_top.v` | FPU top | [Programmer's model](programming.md#floating-point) |
| `rtl/fpu/fpu_fma.v`, `fpu_divsqrt.v`, `fpu_cvt.v`, `fpu_round.v` | multi-cycle units, rounding | [Programmer's model](programming.md#floating-point) |
| `rtl/fpu/fpu_decoder.v`, `fpu_sign_inj.v`, `fpu_min_max.v`, `fpu_compare.v`, `fpu_classifier.v` | operand decoding, single-cycle operations | [Programmer's model](programming.md#floating-point) |
| `rtl/soc/hornet_soc.v` | SoC top | [SoC](soc.md) |
| `rtl/soc/imem.v`, `dmem.v`, `data_router.v`, `obi_axil_bridge.v`, `axil_xbar.v` | memories, data path, bus | [SoC](soc.md) |
| `rtl/soc/axil_timer.v`, `axil_uart.v`, `sync_fifo.v`, `axil_gpio.v`, `axil_sysctl.v` | peripherals | [Peripherals](peripherals.md) |
| `rtl/soc/axil_error_slave.v` | DECERR responder for an unused external port | [Peripherals](peripherals.md#external-axi4-lite-port-0x4000_00000x7fff_ffff) |
| `fpga/common/hornet_board.v` | FPGA top | [FPGA](fpga.md) |

Part II of the student's manual explains each of these blocks: one chapter
per pipeline stage, the CSR unit, the FPU and the SoC internals.

## Abbreviations

| Term | Meaning |
|---|---|
| ALU | arithmetic logic unit |
| AXI4-Lite | the simple, non-burst subset of ARM's AMBA AXI4 bus protocol |
| BRAM | block RAM, the on-chip memory blocks of the FPGA |
| CLINT | core-local interruptor, the standard RISC-V timer and software-interrupt block |
| CPI | cycles per instruction |
| CSR | control and status register |
| DECERR, SLVERR | AXI error responses: no slave at the address; the slave reports an error |
| DSP48 | the multiplier blocks of Xilinx 7-series FPGAs |
| FMA | fused multiply-add: `a × b + c` with one rounding |
| FPU | floating-point unit |
| GRS | guard, round and sticky bits used in rounding |
| ISA | instruction set architecture |
| MMCM | mixed-mode clock manager, the clock synthesiser of the FPGA |
| NaN | not a number |
| PMP | physical memory protection (not implemented) |
| RVFI | RISC-V Formal Interface, a standard retirement trace port |
| Spike | the RISC-V reference instruction-set simulator |
| TestFloat | a program that generates and checks IEEE floating-point test vectors |
| UART | universal asynchronous receiver-transmitter (serial port) |
| WNS | worst negative slack (timing margin) |
