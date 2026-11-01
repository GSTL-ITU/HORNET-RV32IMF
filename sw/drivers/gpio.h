#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>
#include "hornet.h"

// Registers (rtl/soc/axil_gpio.v)
#define GPIO_OUT  REG32(GPIO_BASE + 0x00)
#define GPIO_IN   REG32(GPIO_BASE + 0x04)
#define GPIO_DIR  REG32(GPIO_BASE + 0x08)   // 1 = output
#define GPIO_IE   REG32(GPIO_BASE + 0x0C)   // interrupt enable per pin
#define GPIO_IP   REG32(GPIO_BASE + 0x10)   // interrupt pending, write 1 to clear
#define GPIO_EDGE REG32(GPIO_BASE + 0x14)   // 0 = rising, 1 = falling edge

// Sets the gpio_trigger_o pin high (1) or low (0); pin 0 is LED0 on the Nexys 4 DDR
void gpio_set_trigger(uint8_t state);

void     gpio_set_dir(uint32_t outputs);
void     gpio_write(uint32_t value);
uint32_t gpio_read(void);
void     gpio_set_pin(int pin);
void     gpio_clear_pin(int pin);
void     gpio_toggle_pin(int pin);
void     gpio_irq_enable(uint32_t pins, uint32_t falling);
void     gpio_irq_clear(uint32_t pins);

#endif
