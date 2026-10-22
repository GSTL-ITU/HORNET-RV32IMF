#include "../../drivers/gpio.h"

// Use your contraints to assign gpio_trigger_o to a LED 
// This is a LED blink application
// The delay might need to be changed to see the difference, in case of a clock freq change
void delay(volatile uint32_t count) {
    while (count > 0) {
        count--;
    }
}

int main() {
    uint8_t state = 0;

    while (1) {
        // Toggle the state
        state = !state;
        
        // Write to the hardware
        gpio_set_trigger(state);
        
        // Wait a bit
        delay(500000); 
    }

    return 0; // Should never reach here
}