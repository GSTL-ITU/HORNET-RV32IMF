#include "uart.h"
#define UART_BASE 0x10008010

void uart_init(uart *uart_ptr, uint32_t *base_addr)
{
    uart_ptr->base_addr = base_addr;
}

void uart_transmit_byte(uart *uart_ptr, const uint8_t data)
{
    volatile uint32_t uart_status;
    volatile uint32_t *tx_ptr = (uint32_t*) UART_BASE; 

    while (1)
    {
         asm volatile(
      "   nop             \n" // 1 cycle
      "   nop             \n" // 1 cycle
        );
        if((*((uint32_t*) 0x10008012) & 0x2) != 2){
                 asm volatile(
      "   nop             \n" // 1 cycle
      "   nop             \n" // 1 cycle
        );
            break;}
    }
             asm volatile(
      "   nop             \n" // 1 cycle
      "   nop             \n" // 1 cycle
             );
    // char *tx_ptr = (char *)uart_ptr->base_addr;
    *tx_ptr = data;
}

void uart_transmit_string(uart *uart_ptr, char const *data, size_t len)
{
    for (size_t i = 0; i < len; i++)
    {
        uart_transmit_byte(uart_ptr,*data++);
    }
}
