#include <stdio.h>
#include "hornet.h"

volatile float x = 1.5f, y = 2.25f, z = -0.5f;

int main(void)
{
    printf("Hello from HORNET (id %08lx, %lu Hz)\n", (unsigned long)SYSCTL_ID, (unsigned long)hornet_clk_freq());
    float r = x * y + z;   // fmadd.s
    int ok = r == 2.875f;
    printf("1.5 * 2.25 - 0.5 = %d/1000 %s\n", (int)(r * 1000), ok ? "ok" : "wrong");
    return ok ? 0 : 1;
}
