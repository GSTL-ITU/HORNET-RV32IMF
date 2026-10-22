// HORNET UART bootloader (top 4 KB of IMEM, stack and variables in the top 1 KB of DMEM)
//
// After reset it waits about BOOT_WAIT_MS for the bytes 'H' 'B'. Without them it
// starts the program already in IMEM at address 0. With them it answers 'R' and
// takes commands (little-endian words):
//   'W' addr len data[len] crc32   write a block   -> 'K' ok, 'C' CRC error, 'A' address refused
//   'G' addr                       fence.i and jump -> 'K'
//   'P'                            ping             -> 'R'
// scripts/hornet_load.py is the host side.
#include <stdint.h>
#include "hornet.h"
#include "uart.h"
#include "timer.h"

#ifndef BOOT_WAIT_MS
#define BOOT_WAIT_MS 1000
#endif

extern char __imem_origin[], __dmem_skip[];

static uint32_t crc;

static void crc_byte(uint8_t b)
{
    crc ^= b;
    for (int i = 0; i < 8; i++)
        crc = (crc >> 1) ^ (0xedb88320u & -(crc & 1u));
}

static uint8_t rx(void) { return uart_receive_byte(&uart0); }

static uint32_t rx_word(void)
{
    uint32_t w = 0;
    for (int i = 0; i < 4; i++)
        w |= (uint32_t)rx() << (8 * i);
    return w;
}

static void tx(uint8_t b) { uart_transmit_byte(&uart0, b); }

// writes may go to IMEM below the bootloader and to DMEM below its stack
static int allowed(uint32_t addr, uint32_t len)
{
    uint32_t end = addr + len;
    uint32_t imem_end = (uint32_t)__imem_origin;
    uint32_t dmem_end = DMEM_BASE + (uint32_t)__dmem_skip;
    if (end < addr)
        return 0;
    return (addr >= IMEM_BASE && end <= imem_end) || (addr >= DMEM_BASE && end <= dmem_end);
}

static void start(uint32_t addr)
{
    uart_wait_tx_idle(&uart0);
    __asm__ volatile ("fence.i" ::: "memory");
    ((void (*)(void))addr)();
}

int main(void)
{
    uint64_t deadline = timer_get() + (uint64_t)BOOT_WAIT_MS * (hornet_clk_freq() / 1000u);
    int prev = -1;
    for (;;) {
        int c = uart_try_receive(&uart0);
        if (prev == 'H' && c == 'B')
            break;
        if (c >= 0)
            prev = c;
        if (timer_get() > deadline)
            start(IMEM_BASE);
    }
    tx('R');

    for (;;) {
        uint8_t cmd = rx();
        if (cmd == 'W') {
            uint32_t addr = rx_word();
            uint32_t len = rx_word();
            int ok = allowed(addr, len);
            crc = 0xffffffffu;
            for (uint32_t i = 0; i < len; i++) {
                uint8_t b = rx();
                crc_byte(b);
                if (ok)
                    *(volatile uint8_t *)(addr + i) = b;
            }
            uint32_t sum = rx_word();
            tx(!ok ? 'A' : (sum == ~crc ? 'K' : 'C'));
        } else if (cmd == 'G') {
            uint32_t addr = rx_word();
            tx('K');
            start(addr);
        } else if (cmd == 'P') {
            tx('R');
        }
    }
}
