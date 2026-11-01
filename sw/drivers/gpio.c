#include "gpio.h"

void gpio_set_trigger(uint8_t state) {
    GPIO_DIR |= 1u;
    if (state) {
        GPIO_OUT |= 1u;
    } else {
        GPIO_OUT &= ~1u;
    }
}

void gpio_set_dir(uint32_t outputs) { GPIO_DIR = outputs; }
void gpio_write(uint32_t value) { GPIO_OUT = value; }
uint32_t gpio_read(void) { return GPIO_IN; }
void gpio_set_pin(int pin) { GPIO_OUT |= 1u << pin; }
void gpio_clear_pin(int pin) { GPIO_OUT &= ~(1u << pin); }
void gpio_toggle_pin(int pin) { GPIO_OUT ^= 1u << pin; }

void gpio_irq_enable(uint32_t pins, uint32_t falling)
{
    GPIO_EDGE = falling;
    GPIO_IP = pins;
    GPIO_IE = pins;
}

void gpio_irq_clear(uint32_t pins) { GPIO_IP = pins; }
