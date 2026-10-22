#include "gpio.h"

// This drive is 1-bit write ONLY, as the RTL supoorts.
// For further advanced GPIO needs, change RTL as well as the driver
void gpio_set_trigger(uint8_t state) {
    if (state) {
        *GPIO_REG = 1;
    } else {
        *GPIO_REG = 0;
    }
}