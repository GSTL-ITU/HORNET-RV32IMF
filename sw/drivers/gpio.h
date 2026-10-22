#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>

// Base address mapped from fpga_top.v (Slave 5)
#define GPIO_BASE_ADDR 0x10008020
#define GPIO_REG       ((volatile uint32_t *)GPIO_BASE_ADDR)

// Sets the gpio_trigger_o pin high (1) or low (0)
void gpio_set_trigger(uint8_t state);

#endif 