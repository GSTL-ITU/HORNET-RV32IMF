#include "timer.h"

uint64_t timer_get(void)
{
    uint32_t hi, lo;
    do {
        hi = TIMER_MTIMEH;
        lo = TIMER_MTIME;
    } while (hi != TIMER_MTIMEH);
    return ((uint64_t)hi << 32) | lo;
}

void timer_set_compare(uint64_t value)
{
    TIMER_MTIMECMPH = 0xffffffffu;   // no spurious interrupt while the halves change
    TIMER_MTIMECMP = (uint32_t)value;
    TIMER_MTIMECMPH = (uint32_t)(value >> 32);
}

void timer_set_alarm(uint64_t cycles) { timer_set_compare(timer_get() + cycles); }

void timer_software_irq(int on) { TIMER_MSIP = on ? 1u : 0u; }

void delay_cycles(uint64_t cycles)
{
    uint64_t end = timer_get() + cycles;
    while (timer_get() < end)
        ;
}

void delay_us(uint32_t us) { delay_cycles((uint64_t)us * (hornet_clk_freq() / 1000000u)); }
void delay_ms(uint32_t ms) { delay_cycles((uint64_t)ms * (hornet_clk_freq() / 1000u)); }
