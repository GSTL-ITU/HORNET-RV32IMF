// Counts on the LEDs through a Xilinx AXI GPIO on the external AXI4-Lite port (make fpga-bd)
#include <stdio.h>
#include "hornet.h"
#include "timer.h"

#define AXI_GPIO_DATA REG32(EXT_AXI_BASE + 0x0)
#define AXI_GPIO_TRI  REG32(EXT_AXI_BASE + 0x4)

int main(void)
{
    printf("HORNET: counting on the AXI GPIO LEDs\n");
    AXI_GPIO_TRI = 0;   // all outputs
    for (uint32_t n = 0;; n++) {
        AXI_GPIO_DATA = n;
        delay_ms(100);
    }
}
