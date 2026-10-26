# HORNET software environment

Everything needed to run C on the HORNET SoC: startup code, linker script,
newlib system calls, drivers, build rules, test programs and examples.

```
sw/
├── common.mk        build rules every program includes
├── common/
│   ├── crt0.S       reset entry: gp, stack, FPU on, trap vector, .bss, constructors, main, exit
│   ├── link.ld      IMEM/DMEM layout (sizes from common.mk)
│   └── syscalls.c   printf/scanf on UART0, malloc heap in DMEM, exit, default trap report
├── drivers/         hornet.h (memory map, CSR macros), uart, gpio, timer, irq
├── tests/           self-checking SoC tests (make sw-tests)
└── examples/        student examples (examples/README.md)
```

## A new program

```bash
mkdir sw/examples/myprog && cd sw/examples/myprog
cat > main.c <<'C'
#include <stdio.h>
#include "timer.h"
#include "gpio.h"

int main(void)
{
    printf("hello\n");
    gpio_set_dir(0xffff);
    for (;;) {
        gpio_toggle_pin(0);
        delay_ms(250);
    }
}
C
printf 'include ../../common.mk\n' > Makefile
make
```

Variables a program's Makefile can set before `include`:

| Variable | Default | Meaning |
|---|---|---|
| `PROG` | directory name | output name |
| `SRCS` | all `*.c` and `*.S` | sources (the drivers are always linked) |
| `IMEM_SIZE`, `DMEM_SIZE` | `0x10000` each | memory sizes; the simulation and the bitstream use the same values |
| `STACK_SIZE` | `0x1000` | reserved at the top of DMEM |
| `OPT` | `-O2` | optimisation |
| `FLOAT_PRINTF` | `0` | `1` lets `printf` print `%f` (larger program) |

`make` runs the compiler in the `hornet-dev` Docker image when it is called on
the host (`USE_DOCKER=0` uses a local `riscv32-unknown-elf-gcc` with the
`rv32imf_zicsr/ilp32f` multilib instead).

Programs outside this repository include `common.mk` by its path
(`include <HORNET>/sw/common.mk`). Docker then mounts `SRC_ROOT` (default: the
program directory; set it to the root of the other repository when sources
come from directories above) at its own path, and `make sim` runs the SoC
testbench on the images there. `SIM_ARGS` passes plusargs to the testbench
(`SIM_ARGS="+timeout=10000000000"` for long programs). The PQC benchmarks in
[common-pqc-lib-riscv](https://github.com/GSTL-ITU/common-pqc-lib-riscv) are
built this way.

## Memory map

| Address | Size | |
|---|---|---|
| `0x0000_0000` | `IMEM_SIZE` | instruction memory: code, constants (`.rodata`); reset vector at 0 |
| `0x1000_0000` | `DMEM_SIZE` | data memory: `.data`, `.bss`, heap, stack (top) |
| `0x2000_0000` | 64 KB | timer (CLINT layout): `msip`, `mtimecmp` (+`0x4000`), `mtime` (+`0xBFF8`) |
| `0x2001_0000` | 64 KB | UART: DATA, STATUS, CTRL, DIV |
| `0x2002_0000` | 64 KB | GPIO: OUT, IN, DIR, IE, IP, EDGE |
| `0x2003_0000` | 64 KB | system control: EXIT, CLK_FREQ, ID, SCRATCH |
| `0x4000_0000` | 1 GB | external AXI4-Lite port (Vivado IP in a block design) |

Register details are in the headers in `drivers/` and in the RTL headers of
`rtl/soc/axil_*.v`.

## Interrupts and traps

`crt0` points `mtvec` at a default handler that prints `mcause`, `mepc` and
`mtval` and stops. Programs take over with the helpers of `irq.h`:

```c
#include "irq.h"
void mti_handler() { /* timer */ timer_set_compare(~0ull); }

SET_MTVEC_VECTOR_MODE();   // vector table in irq.c, handlers are weak functions
ENABLE_MTI();
ENABLE_GLOBAL_IRQ();
timer_set_alarm(hornet_clk_freq());   // one second
```

| Interrupt | `mcause` | Handler |
|---|---|---|
| software (`msip`) | 3 | `msi_handler` |
| timer | 7 | `mti_handler` |
| external pin `meip_i` | 11 | `mei_handler` |
| UART (RX data / TX empty, `uart_set_irq`) | 16 | `fast_irq0_handler` |
| GPIO edges (`gpio_irq_enable`) | 17 | `fast_irq1_handler` |
| pins `irq_i[13:0]` | 18..31 | `fast_irq2_handler` .. `fast_irq15_handler` |

Exceptions (illegal instruction, misaligned or faulting access, `ecall`,
`ebreak`) go to `exc_handler` in vectored mode and to `direct_trap_handler` in
direct mode. The handler of an exception must advance `mepc` itself.

Handlers declared with `interrupt("machine")` save the integer registers they
use; an interrupt handler that uses floating point should save and restore
`fcsr` as well.

## Notes

- Misaligned loads and stores trap. GCC is called with `-mstrict-align`, so C
  code never produces them.
- Fused multiply-add is in hardware; there is no need for `-ffp-contract=off`.
- `mstatus.FS` is Off after reset; `crt0` turns the FPU on. Assembly programs
  without `crt0` must set it before the first FP instruction.
- `hornet_cycles()` and `hornet_instret()` read the 64-bit counters,
  `hornet_clk_freq()` the clock frequency of the SoC.
