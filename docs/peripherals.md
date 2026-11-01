# Peripherals

All peripherals are AXI4-Lite [[AXI]](references.md#bus-and-peripheral-standards) slaves with 32-bit registers. An access to
an offset that does not exist answers `SLVERR`, which the core reports as a
load or store access fault (`mcause` 5 or 7, `mtval` = address). The C
headers in `sw/drivers/` define the same registers
([Software: drivers](software.md#drivers-swdrivers)).

## Timer (`0x2000_0000`, `axil_timer.v`)

A machine timer and software interrupt in the register layout of the
RISC-V CLINT (core-local interruptor) [[CLINT]](references.md#risc-v-specifications) [[ACLINT]](references.md#risc-v-specifications), which
is what standard RISC-V software expects.

| Offset | Register | Access | Description |
|---|---|---|---|
| `0x0000` | `msip` | RW | bit 0: machine software interrupt (MSI) |
| `0x4000` | `mtimecmp` | RW | compare value, low word; reset `0xFFFF_FFFF` |
| `0x4004` | `mtimecmph` | RW | compare value, high word; reset `0xFFFF_FFFF` |
| `0xBFF8` | `mtime` | RW | cycle counter, low word |
| `0xBFFC` | `mtimeh` | RW | cycle counter, high word |

`mtime` increases by one every clock cycle (`CLK_FREQ` per second,
readable in system control) and is also the `time` CSR. The timer
interrupt (MTI) is pending while `mtime >= mtimecmp` (64-bit unsigned);
writing a later compare value removes it. To set a new compare value
without a spurious interrupt, write the high word first with all ones, then
the low word, then the high word (`timer_set_compare()` does this).

## UART (`0x2001_0000`, `axil_uart.v`)

Asynchronous serial [[UART]](references.md#bus-and-peripheral-standards): 8 data bits, no parity, 1 stop bit
(8N1), 16-byte FIFOs for transmit and receive. The reset baud rate is the `BAUD` parameter of `hornet_soc`
(115200).

| Offset | Register | Access | Description |
|---|---|---|---|
| `0x00` | DATA | W | append a byte to the TX FIFO (dropped when the FIFO is full) |
| | | R | next byte of the RX FIFO in bits 7:0; bit 31 = 1 when the FIFO was empty |
| `0x04` | STATUS | R | 0: RX data available, 1: TX FIFO full, 2: TX idle (FIFO empty and line idle), 3: RX overrun, 4: frame error |
| | | W | writing 1 to bit 3 or 4 clears it |
| `0x08` | CTRL | RW | 0: interrupt while RX data is available; 1: interrupt while the TX FIFO is empty |
| `0x0C` | DIV | RW | clock cycles per bit (16 bits); `uart_set_baud()` computes `CLK_FREQ / baud` |

The interrupt (fast interrupt 0, `mcause 0x8000_0010`) is a level, high
while `(CTRL[0] and RX not empty) or (CTRL[1] and TX empty)`. An RX handler
reads DATA until the FIFO is empty, or one byte per interrupt. A byte that
arrives while the RX FIFO is full is dropped and sets *overrun*; a byte
with an invalid stop bit is dropped and sets *frame error*.

## GPIO (`0x2002_0000`, `axil_gpio.v`)

32 general-purpose bits. On the board top (Nexys 4 DDR) outputs 15:0 drive
the LEDs, inputs 15:0 are the switches, inputs 20:16 the buttons C, U, L, R,
D, and bits 31:24 the Pmod JA connector (bidirectional). The Nexys Video has
8 LEDs and 8 switches.

| Offset | Register | Access | Description |
|---|---|---|---|
| `0x00` | OUT | RW | output values |
| `0x04` | IN | R | input values (synchronised) |
| `0x08` | DIR | RW | 1 = the pin drives OUT (used for the tri-state Pmod pins) |
| `0x0C` | IE | RW | interrupt enable per pin |
| `0x10` | IP | RW | edge seen per pin; write 1 to clear |
| `0x14` | EDGE | RW | 0 = rising, 1 = falling edge per pin |

An edge of the selected direction on an input sets its bit in IP. The
interrupt (fast interrupt 1, `mcause 0x8000_0011`) is high while `IP & IE`
is not zero; the handler clears the bits it served by writing 1 to them.

## System control (`0x2003_0000`, `axil_sysctl.v`)

| Offset | Register | Access | Description |
|---|---|---|---|
| `0x00` | EXIT | RW | a write ends a simulation; the value is the exit code (0 = PASS); no effect on the board |
| `0x04` | CLK_FREQ | R | clock frequency in Hz (`CLK_FREQ` parameter, read by `hornet_clk_freq()`) |
| `0x08` | ID | R | `0x4852_4E54` ("HRNT") |
| `0x0C` | SCRATCH | RW | free |

`exit()` in the C library writes EXIT, so a program that returns from
`main` ends the SoC simulation with its return value.

## External AXI4-Lite port (`0x4000_0000`–`0x7FFF_FFFF`)

The `m_axi_*` ports of `hornet_soc` form an AXI4-Lite master with one
transaction at a time. In a Vivado block design, Xilinx AXI IP (AXI GPIO,
AXI UART Lite, AXI Timer, AXI BRAM controller) or custom AXI4-Lite IP is
placed in this range with the Address Editor [[UG994]](references.md#fpga-and-boards); an AXI
SmartConnect [[PG247]](references.md#fpga-and-boards) is needed for more than one slave ([FPGA: HORNET as a Vivado IP](fpga.md#hornet-as-a-vivado-ip)).
On the plain board top the port answers `DECERR`.

## Adding a peripheral

The AXI4-Lite interconnect `axil_xbar` selects a slave when
`(address & MASK) == BASE`; the first match wins, and an address that
matches no slave is answered with `DECERR`. `hornet_soc` has five slots:

| Slot | Slave | `BASE` | `MASK` |
|---|---|---|---|
| 0 | timer | `0x2000_0000` | `0xFFFF_0000` |
| 1 | UART | `0x2001_0000` | `0xFFFF_0000` |
| 2 | GPIO | `0x2002_0000` | `0xFFFF_0000` |
| 3 | external `m_axi` | `0x4000_0000` | `0xC000_0000` |
| 4 | system control | `0x2003_0000` | `0xFFFF_0000` |

1. Write an AXI4-Lite slave with 32-bit registers (the existing peripherals
   are good templates: they accept a write when AWVALID and WVALID are both
   high, answer `SLVERR` for unknown offsets, and keep one read in flight).
2. In `hornet_soc.v`, increase `N` of `axil_xbar`, add its `BASE` and
   `MASK`, and connect the new slice of the `x_*` buses.
3. Add the register addresses to a header in `sw/drivers/` and a test in
   `sw/tests/`.
4. For a peripheral outside the RTL (Vivado IP), none of this is needed:
   connect it to the `m_axi` port and give it an address in
   `0x4000_0000`–`0x7FFF_FFFF`.
