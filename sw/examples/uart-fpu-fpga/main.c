#include "../../drivers/uart.h"
#include "../../drivers/irq.h"
#include <stdint.h>

// --- UART Configuration ---
#define UART_ADDR 0x10008010
#define INPUT_FLOATS 3  // We will receive A, B, and C
#define OUTPUT_FLOATS 5 // We will send Add, Sub, Mul, Div, Sqrt
#define BYTES_TO_RX (INPUT_FLOATS * 4)

volatile int rx_count;
volatile float input_array[INPUT_FLOATS];

typedef union {
    float f;
    uint8_t bytes[4];
} float_bytes_t;

volatile float_bytes_t rx_var;
uart uart0;

// =============================================================================
// INTERRUPT SERVICE ROUTINE 
// =============================================================================
void mti_handler() {}
void exc_handler() {}
void mei_handler() {}
void msi_handler() {}
void fast_irq1_handler() {}

void fast_irq0_handler() {
    // Read Byte directly from UART RX register
    char *rx_ptr = (char*)(uart0.base_addr) + UART_RX_ADDR_OFFSET;
    char rx_byte = *rx_ptr;
    
    // Assemble the float byte by byte
    rx_var.bytes[rx_count % 4] = rx_byte;

    // Once 4 bytes are gathered, store the complete float
    if ((rx_count % 4) == 3) {
        input_array[rx_count / 4] = rx_var.f;
    }

    rx_count++;
    
    // Disable interrupts when the expected payload is fully received
    if (rx_count >= BYTES_TO_RX) {
        DISABLE_GLOBAL_IRQ();
    }
}

// =============================================================================
// MAIN EXECUTION LOOP
// =============================================================================
int main() {
    // Setup Interrupt Vector and UART
    SET_MTVEC_VECTOR_MODE();
    uart_init(&uart0, (uint32_t *) UART_ADDR);

    while(1) {
        // 1. Reset state and wait for data from Python
        rx_count = 0;
        ENABLE_GLOBAL_IRQ();
        ENABLE_FAST_IRQ(0); 
        
        while(rx_count < BYTES_TO_RX) {
            // Block until 12 bytes (3 floats) are received
            continue; 
        }
        
        // 2. Extract inputs
        float a = input_array[0];
        float b = input_array[1];
        float c = input_array[2];
        
        // 3. Perform Hardware FPU Math
        float_bytes_t results[OUTPUT_FLOATS];
        results[0].f = a + b;                  // fadd.s
        results[1].f = a - b;                  // fsub.s
        results[2].f = a * c;                  // fmul.s
        results[3].f = a / c;                  // fdiv.s
        results[4].f = __builtin_sqrtf(a);     // fsqrt.s (GCC intrinsic for square root)
        
        // 4. Send the 5 resulting floats (20 bytes) back to Python
        for (int i = 0; i < OUTPUT_FLOATS; i++) {
            for (int byte_idx = 0; byte_idx < 4; byte_idx++) {
                uart_transmit_byte(&uart0, results[i].bytes[byte_idx]);
            }
        }
    }
    
    return 0;
}