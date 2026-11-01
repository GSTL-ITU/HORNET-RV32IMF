// Code written through the data port into IMEM runs after fence.i
#include <stdio.h>
#include <stdint.h>

int ram_fn(void);
__asm__(".section .text.ram, \"ax\"\n.align 2\nram_fn:\n    li a0, 0\n    ret\n.text\n");

int main(void)
{
    volatile uint32_t *p = (volatile uint32_t *)ram_fn;
    int before = ram_fn();
    p[0] = 0x02a00513;                    // li a0, 42
    __asm__ volatile ("fence.i" ::: "memory");
    int after = ram_fn();
    printf("before %d after %d %s\n", before, after, before == 0 && after == 42 ? "ok" : "FAILED");
    return !(before == 0 && after == 42);
}
