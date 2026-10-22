#include "uart.h"

#define UART_REG(u, off) (*(volatile uint32_t *)((uintptr_t)(u)->base_addr + (off)))

uart uart0 = { (uint32_t *)UART0_BASE };

void uart_init(uart *uart_ptr, uint32_t *base_addr)
{
    uart_ptr->base_addr = base_addr;
}

void uart_set_baud(uart *uart_ptr, uint32_t baud)
{
    UART_REG(uart_ptr, UART_DIV_OFFSET) = hornet_clk_freq() / baud;
}

void uart_transmit_byte(uart *uart_ptr, const uint8_t data)
{
    while (UART_REG(uart_ptr, UART_STATUS_OFFSET) & UART_TX_FULL)
        ;
    UART_REG(uart_ptr, UART_DATA_OFFSET) = data;
}

void uart_transmit_string(uart *uart_ptr, char const *data, size_t len)
{
    for (size_t i = 0; i < len; i++)
    {
        uart_transmit_byte(uart_ptr,*data++);
    }
}

void uart_puts(uart *uart_ptr, char const *str)
{
    while (*str)
        uart_transmit_byte(uart_ptr, *str++);
}

int uart_rx_available(uart *uart_ptr)
{
    return (UART_REG(uart_ptr, UART_STATUS_OFFSET) & UART_RX_AVAIL) != 0;
}

uint8_t uart_receive_byte(uart *uart_ptr)
{
    uint32_t v;
    do {
        v = UART_REG(uart_ptr, UART_DATA_OFFSET);
    } while (v & 0x80000000u);
    return (uint8_t)v;
}

int uart_try_receive(uart *uart_ptr)
{
    uint32_t v = UART_REG(uart_ptr, UART_DATA_OFFSET);
    return (v & 0x80000000u) ? -1 : (int)(v & 0xff);
}

void uart_wait_tx_idle(uart *uart_ptr)
{
    while (!(UART_REG(uart_ptr, UART_STATUS_OFFSET) & UART_TX_IDLE))
        ;
}

void uart_set_irq(uart *uart_ptr, uint32_t ctrl_bits)
{
    UART_REG(uart_ptr, UART_CTRL_OFFSET) = ctrl_bits;
}
