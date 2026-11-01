// External AXI4-Lite port, access faults and misaligned accesses
#include <stdio.h>
#include "hornet.h"
#include "irq.h"

volatile uint32_t causes[8], tvals[8];
volatile int traps;

void direct_trap_handler()
{
    causes[traps & 7] = read_csr(mcause);
    tvals[traps & 7] = read_csr(mtval);
    traps++;
    write_csr(mepc, read_csr(mepc) + 4);
}

int main(void)
{
    int errors = 0;
    volatile uint32_t *ext = (volatile uint32_t *)EXT_AXI_BASE;
    volatile uint8_t *ext8 = (volatile uint8_t *)EXT_AXI_BASE;
    volatile uint16_t *ext16 = (volatile uint16_t *)EXT_AXI_BASE;

    for (int i = 0; i < 16; i++)
        ext[i] = 0x01010101u * i ^ 0xa5a5a5a5u;
    for (int i = 0; i < 16; i++)
        if (ext[i] != (0x01010101u * i ^ 0xa5a5a5a5u))
            errors++;
    ext8[3] = 0x5a;
    ext16[3] = 0xbeef;
    if (ext[0] != 0x5aa5a5a5u || ext[1] != 0xbeefa4a4u || ext8[1] != 0xa5 || ext16[1] != 0x5aa5)
        errors++;
    printf("external RAM %s\n", errors ? "FAILED" : "ok");

    SET_MTVEC_DIRECT_MODE();
    volatile uint32_t *slverr = (volatile uint32_t *)0x41000000u;
    volatile uint32_t *hole = (volatile uint32_t *)0x20040000u;
    volatile uint32_t *none = (volatile uint32_t *)0x30000000u;
    volatile uint32_t *mis = (volatile uint32_t *)0x10000102u;
    uint32_t v;
    *slverr = 1;          // store access fault (SLVERR)
    v = *slverr;          // load access fault
    v = *hole;            // DECERR inside the peripheral region
    *none = v;            // nothing mapped
    __asm__ volatile ("lw %0, 0(%1)" : "=r"(v) : "r"(mis)); // misaligned load (the compiler would split it)
    (void)v;

    const uint32_t want_cause[5] = {7, 5, 5, 7, 4};
    const uint32_t want_tval[5] = {0x41000000u, 0x41000000u, 0x20040000u, 0x30000000u, 0x10000102u};
    for (int i = 0; i < 5; i++) {
        int ok = causes[i] == want_cause[i] && tvals[i] == want_tval[i];
        printf("trap %d mcause=%lu mtval=%08lx %s\n", i, (unsigned long)causes[i], (unsigned long)tvals[i], ok ? "ok" : "FAILED");
        errors += !ok;
    }
    errors += traps != 5;
    return errors;
}
