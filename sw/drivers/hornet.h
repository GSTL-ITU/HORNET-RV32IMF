#ifndef HORNET_H
#define HORNET_H

#include <stdint.h>

// Memory map (rtl/soc/hornet_soc.v)
#define IMEM_BASE    0x00000000u
#define DMEM_BASE    0x10000000u
#define TIMER_BASE   0x20000000u
#define UART0_BASE   0x20010000u
#define GPIO_BASE    0x20020000u
#define SYSCTL_BASE  0x20030000u
#define EXT_AXI_BASE 0x40000000u   // external AXI4-Lite port (Vivado IP)

#define REG32(addr) (*(volatile uint32_t *)(addr))

// System control
#define SYSCTL_EXIT     REG32(SYSCTL_BASE + 0x0)
#define SYSCTL_CLK_FREQ REG32(SYSCTL_BASE + 0x4)
#define SYSCTL_ID       REG32(SYSCTL_BASE + 0x8)
#define SYSCTL_SCRATCH  REG32(SYSCTL_BASE + 0xC)

// CSR access
#define read_csr(reg) ({ uint32_t __v; __asm__ volatile ("csrr %0, " #reg : "=r"(__v)); __v; })
#define write_csr(reg, val) __asm__ volatile ("csrw " #reg ", %0" :: "rK"(val))
#define set_csr(reg, bits) __asm__ volatile ("csrs " #reg ", %0" :: "rK"(bits))
#define clear_csr(reg, bits) __asm__ volatile ("csrc " #reg ", %0" :: "rK"(bits))

// Clock frequency in Hz, read from the SoC
static inline uint32_t hornet_clk_freq(void) { return SYSCTL_CLK_FREQ; }

// 64-bit cycle and instruction counters
static inline uint64_t hornet_cycles(void)
{
    uint32_t hi, lo, hi2;
    do {
        hi = read_csr(mcycleh);
        lo = read_csr(mcycle);
        hi2 = read_csr(mcycleh);
    } while (hi != hi2);
    return ((uint64_t)hi << 32) | lo;
}

static inline uint64_t hornet_instret(void)
{
    uint32_t hi, lo, hi2;
    do {
        hi = read_csr(minstreth);
        lo = read_csr(minstret);
        hi2 = read_csr(minstreth);
    } while (hi != hi2);
    return ((uint64_t)hi << 32) | lo;
}

// Ends a simulation with an exit code (no effect on the board)
static inline void hornet_exit(uint32_t code) { SYSCTL_EXIT = code; }

#endif
