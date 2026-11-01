#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>
#include "hornet.h"

// Registers (rtl/soc/axil_timer.v, CLINT layout); mtime counts clock cycles
#define TIMER_MSIP      REG32(TIMER_BASE + 0x0000)
#define TIMER_MTIMECMP  REG32(TIMER_BASE + 0x4000)
#define TIMER_MTIMECMPH REG32(TIMER_BASE + 0x4004)
#define TIMER_MTIME     REG32(TIMER_BASE + 0xBFF8)
#define TIMER_MTIMEH    REG32(TIMER_BASE + 0xBFFC)

uint64_t timer_get(void);
void     timer_set_compare(uint64_t value);   // machine timer interrupt when mtime >= value
void     timer_set_alarm(uint64_t cycles);    // compare = now + cycles
void     timer_software_irq(int on);
void     delay_cycles(uint64_t cycles);
void     delay_us(uint32_t us);
void     delay_ms(uint32_t ms);

#endif
