// =============================================================================
// RISC-V FPGA INFERENCE (FOLDED / NO-BATCH / NO-SOFTMAX)
// =============================================================================

#ifndef USE_KERAS_LAYOUT
#define USE_KERAS_LAYOUT 1
#endif

#include "MLP_weights_folded.h" 

#include "../../drivers/uart.h"
#include "../../drivers/irq.h"
#include <stdint.h>

#define DEBUG_IF_ADDR 0x10008010 

// --- Dimensions ---
#define INPUT_DIM 122
#define L0_OUT    256 
#define L1_OUT    128 
#define L2_OUT    64  
#define L3_OUT    32  
#define L4_OUT    5   

// --- UART/Buffer State ---
#define TOTAL_BYTES_TO_RECEIVE (INPUT_DIM * 4) // 122 * 4 = 488 bytes

volatile int count;
volatile float input_array[INPUT_DIM]; // Buffer for UART data

typedef union {
    float f;           
    uint8_t bytes[4];  
} float_bytes_t;

volatile float_bytes_t rx_var;
uart uart0;

// =============================================================================
// LIGHTWEIGHT MATH HELPERS 
// =============================================================================

float relu(float x){ return x > 0.0f ? x : 0.0f; }

void dense_affine(const float *x, int in_dim,
                  const float *w, const float *b,
                  int out_dim, float *y)
{

// We prefered using TensorFlow/Keras layout for weights, but
// some users might have transposed weights. Support both. This 
// has to be design according your Python export script.

    #if USE_KERAS_LAYOUT
    // Keras Layout
    for (int o = 0; o < out_dim; ++o) {
        float acc = b[o];
        for (int i = 0; i < in_dim; ++i)
            acc += x[i] * w[i * out_dim + o];
        y[o] = acc;
    }
#else
    // Transposed Layout
    for (int o = 0; o < out_dim; ++o) {
        float acc = b[o];
        const float *wrow = &w[o * in_dim];
        for (int i = 0; i < in_dim; ++i)
            acc += wrow[i] * x[i];
        y[o] = acc;
    }
#endif
}

// =============================================================================
// INFERENCE ENGINE
// =============================================================================
int model_infer(const float *x)
{
    // Define buffers locally
    // Note: In this design we did not get stack overflow.
    // If you get stack overflow, move these outside the function.
    float z0[L0_OUT];
    float z1[L1_OUT];
    float z2[L2_OUT];
    float z3[L3_OUT];
    float logits[L4_OUT];
    
    // Layer 0: Folded Dense -> ReLU
    dense_affine(x, INPUT_DIM, layer0_weights, layer0_biases, L0_OUT, z0);
    for (int i=0; i<L0_OUT; ++i) z0[i] = relu(z0[i]);

    // Layer 1: Folded Dense -> ReLU
    dense_affine(z0, L0_OUT, layer1_weights, layer1_biases, L1_OUT, z1);
    for (int i=0; i<L1_OUT; ++i) z1[i] = relu(z1[i]);

    // Layer 2: Folded Dense -> ReLU
    dense_affine(z1, L1_OUT, layer2_weights, layer2_biases, L2_OUT, z2);
    for (int i=0; i<L2_OUT; ++i) z2[i] = relu(z2[i]);

    // Layer 3: Folded Dense -> ReLU
    dense_affine(z2, L2_OUT, layer3_weights, layer3_biases, L3_OUT, z3);
    for (int i=0; i<L3_OUT; ++i) z3[i] = relu(z3[i]);

    // Layer 4: Output (Logits only)
    dense_affine(z3, L3_OUT, layer4_weights, layer4_biases, L4_OUT, logits);

    
    // Since we only need the predicted class, we can skip softmax.
    // The max probability corresponds to the max logit even without softmax.
    int predicted = 0;
    float max_val = logits[0];
    for (int i = 1; i < L4_OUT; ++i) {
        if (logits[i] > max_val) {
            max_val = logits[i];
            predicted = i;
        }
    }

    return predicted;
}

// =============================================================================
// MAIN EXECUTION LOOP
// =============================================================================
int main() {
    // Setup
    SET_MTVEC_VECTOR_MODE();
    count = 0;
    uart_init(&uart0, (uint32_t *) 0x10008010);

    // Hardcoded Test Vector (To verify boot/logic without UART)
    // This ensures your FPGA is alive immediately after bitstream load.
    // We used for debugging. Its neither necessary nor useful. But I keep it for sake of 
    // easy illustration of debugging process.
    float test_input[INPUT_DIM] = { 
        0.000000f, 1.000000f, 0.000000f, 0.000000f, 0.000000f, 
        0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 
        0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 
        0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 
        0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 
        0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 
        0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 1.000000f, 
        0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 
        0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 
        0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 1.000000f, 0.000000f, 0.000000f, 
        0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, 0.000000f, -0.110249f, 
        -0.007762f, -0.004919f, -0.014089f, -0.089486f, -0.007736f, -0.095076f, -0.027023f, -0.809262f, 
        -0.011664f, -0.036652f, -0.024437f, -0.012385f, -0.026180f, -0.018610f, -0.041221f, 0.000000f, 
        -0.002817f, -0.097531f, 1.265346f, -0.244204f, -0.637209f, -0.631929f, 2.746403f, 2.715365f, 
        -1.412415f, -0.016930f, -0.374560f, 0.734343f, -0.954389f, -1.071933f, -0.121485f, -0.480197f, 
        -0.289103f, -0.639532f, -0.624871f, 2.874410f, 2.753914f 
    };
    
    // Run self-test
    int boot_result = model_infer(test_input);
    uart_transmit_byte(&uart0, (uint8_t) boot_result);

    // Main UART Loop
    while(1)
    {
        // Reset counter and Enable Interrupts to start receiving
        count = 0;
        ENABLE_GLOBAL_IRQ();
        ENABLE_FAST_IRQ(0); 
        
        // Wait until buffer is full (488 bytes)
        // The ISR will disable interrupts when done.
        while(count < TOTAL_BYTES_TO_RECEIVE) {
            // For debugging, you can add a GPIO module here to toggle a pin or LED.
            continue; 
        }
        
        // --- Data Received ---
        // Run Inference
        int result = model_infer((float*)input_array);
        
        // Send Result
        uart_transmit_byte(&uart0, (uint8_t) result);
    }
    
    return 0;
}

// =============================================================================
// INTERRUPT SERVICE ROUTINE 
// =============================================================================

void mti_handler() {}
void exc_handler() {}
void mei_handler() {}
void msi_handler() {}

void fast_irq0_handler()
{
    // Read Byte
    char *rx_ptr = (char*)(uart0.base_addr) + UART_RX_ADDR_OFFSET;
    char rx_byte = *rx_ptr;
    
    // Assembly Float
    rx_var.bytes[count % 4] = rx_byte;

    //  Store to Array 
    input_array[count / 4] = rx_var.f;

    // Increment & Check
    count++;
    
    if (count >= TOTAL_BYTES_TO_RECEIVE) {
        // Buffer Full
        DISABLE_GLOBAL_IRQ();
    }
}

void fast_irq1_handler() {}