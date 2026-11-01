#include "../../drivers/gpio.h"

// Using volatile pointers forces the compiler to emit actual FPU memory instructions 
// rather than optimizing the sort away at compile time.
void bubble_sort(volatile float* arr, int len) {
    int sort_num;
    do {
        sort_num = 0;
        for(int i = 0; i < len - 1; i++) {
            // Hardware FPU comparison instruction expected here
            if(arr[i] > arr[i+1]) {
                // Hardware FPU load/store instructions expected here
                float tmp = arr[i];
                arr[i] = arr[i+1];
                arr[i+1] = tmp;
                sort_num++;
            }
        } 
    } while(sort_num != 0);
}

// Custom array comparison for floats
int check_arrays_equal(volatile float* arr1, volatile float* arr2, int len) {
    for (int i = 0; i < len; i++) {
        // Direct equality '!=' is safe here because we are only swapping exact 
        // values around, not performing math that introduces precision drift.
        if (arr1[i] != arr2[i]) {
            return 0; // Arrays do not match
        }
    }
    return 1; // Arrays match perfectly
}

int main() {
    // Initialize floating-point arrays. 
    volatile float unsorted_arr[] = {195.5f, 14.1f, 176.8f, 103.0f, 54.4f, 32.2f, 128.9f};
    volatile float sorted_arr[]   = {14.1f, 32.2f, 54.4f, 103.0f, 128.9f, 176.8f, 195.5f};
    int len = 7;

    // Turn LED off
    gpio_set_trigger(0);

    // Run the FPU sort
    bubble_sort(unsorted_arr, len);

    // Verify results and drive GPIO
    if (check_arrays_equal(unsorted_arr, sorted_arr, len)) {
        // Success! Turn LED ON
        gpio_set_trigger(1);
    } else {
        // Failure! Keep LED OFF
        gpio_set_trigger(0);
    }

    // Halt processor execution
    while(1) {
        // Infinite loop trap
    }

    return 0;
}