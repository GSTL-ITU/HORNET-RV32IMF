# HORNET peripherals

All peripherals are AXI4-Lite slaves with 32-bit registers
([ADR-0010](decisions/0010-peripherals-software.md)). An access to an
offset that does not exist answers `SLVERR`, which the core reports as a
load or store access fault (`mcause` 5 or 7, `mtval` = address). The C
headers in `sw/drivers/` define the same registers.

## Timer (`0x2000_0000`, `rtl/soc/axil_timer.v`)

CLINT register layout. `mtime` counts clock cycles (`SYSCTL CLK_FREQ` per second).

| Offset | Register | Access | |
|---|---|---|---|
| `0x0000` | `msip` | RW | bit 0: machine software interrupt |
| `0x4000` | `mtimecmp` | RW | low word; reset `0xFFFF_FFFF` |
| `0x4004` | `mtimecmph` | RW | high word; reset `0xFFFF_FFFF` |
| `0xBFF8` | `mtime` | RW | low word |
| `0xBFFC` | `mtimeh` | RW | high word |

The timer interrupt is pending while `mtime >= mtimecmp`; writing a later
compare value clears it (`timer_set_compare()` writes the high word first,
so no spurious interrupt happens in between).

## UART (`0x2001_0000`, `rtl/soc/axil_uart.v`)

8 data bits, no parity, 1 stop bit, 16-byte RX and TX FIFOs. The reset baud
rate is the `BAUD` parameter of `hornet_soc` (115200).

| Offset | Register | Access | |
|---|---|---|---|
| `0x00` | DATA | W | append a byte to the TX FIFO (dropped when full) |
| | | R | next byte of the RX FIFO in bits 7:0; bit 31 = 1 when the FIFO was empty |
| `0x04` | STATUS | R | 0 RX data available, 1 TX FIFO full, 2 TX idle (FIFO empty, line idle), 3 RX overrun, 4 frame error |
| | | W | writing 1 to bit 3 or 4 clears it |
| `0x08` | CTRL | RW | 0 interrupt while RX data available, 1 interrupt while the TX FIFO is empty |
| `0x0C` | DIV | RW | clock cycles per bit (`uart_set_baud()` computes it) |

The interrupt (fast interrupt 0, `mcause 0x8000_0010`) is a level: an RX
handler reads DATA until the FIFO is empty or reads one byte per interrupt.

## GPIO (`0x2002_0000`, `rtl/soc/axil_gpio.v`)

32 bits; on the board top (Nexys 4 DDR; the Nexys Video has 8 of each): outputs 15:0 are the LEDs, inputs 15:0 the
switches, inputs 20:16 the buttons C, U, L, R, D, and bits 31:24 Pmod JA.

| Offset | Register | Access | |
|---|---|---|---|
| `0x00` | OUT | RW | output values |
| `0x04` | IN | R | input values (synchronised) |
| `0x08` | DIR | RW | 1 = pin drives OUT (Pmod JA tri-state) |
| `0x0C` | IE | RW | interrupt enable per pin |
| `0x10` | IP | RW | edge seen per pin; write 1 to clear |
| `0x14` | EDGE | RW | 0 = rising, 1 = falling edge per pin |

The interrupt (fast interrupt 1, `mcause 0x8000_0011`) is pending while
`IP & IE` is non-zero.

## System control (`0x2003_0000`, `rtl/soc/axil_sysctl.v`)

| Offset | Register | Access | |
|---|---|---|---|
| `0x00` | EXIT | RW | a write ends a simulation (0 = PASS); no effect on the board |
| `0x04` | CLK_FREQ | R | clock frequency in Hz (`hornet_clk_freq()`) |
| `0x08` | ID | R | `0x4852_4E54` ("HRNT") |
| `0x0C` | SCRATCH | RW | free |

## External AXI4-Lite port (`0x4000_0000`–`0x7FFF_FFFF`)

`m_axi_*` of `hornet_soc`: an AXI4-Lite master, one transaction at a time.
In a Vivado block design, Xilinx AXI IP (AXI GPIO, AXI UART Lite, AXI Timer,
AXI BRAM controller, your own AXI4-Lite IP) is placed in this range with the
Address Editor. On the plain board top the port answers `DECERR`.
