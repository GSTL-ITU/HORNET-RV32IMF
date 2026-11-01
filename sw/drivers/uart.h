#ifndef UART_H
#define UART_H

#include <stdlib.h>
#include <stdint.h>
#include "hornet.h"

// Register offsets (bytes)
#define UART_DATA_OFFSET   0x0
#define UART_STATUS_OFFSET 0x4
#define UART_CTRL_OFFSET   0x8
#define UART_DIV_OFFSET    0xC

// STATUS bits
#define UART_RX_AVAIL  (1u << 0)
#define UART_TX_FULL   (1u << 1)
#define UART_TX_IDLE   (1u << 2)
#define UART_OVERRUN   (1u << 3)
#define UART_FRAME_ERR (1u << 4)

// CTRL bits
#define UART_RX_IRQ (1u << 0)
#define UART_TX_IRQ (1u << 1)

typedef struct uart
{
    uint32_t *base_addr;
}uart;

// The UART used by printf (syscalls.c)
extern uart uart0;

void uart_init(uart *uart_ptr, uint32_t *base_addr);
void uart_set_baud(uart *uart_ptr, uint32_t baud);
void uart_transmit_byte(uart *uart_ptr, const uint8_t data);
void uart_transmit_string(uart *uart_ptr, char const *data, size_t len);
void uart_puts(uart *uart_ptr, char const *str);
int  uart_rx_available(uart *uart_ptr);
uint8_t uart_receive_byte(uart *uart_ptr);   // waits for a byte
int  uart_try_receive(uart *uart_ptr);       // -1 when nothing was received
void uart_wait_tx_idle(uart *uart_ptr);
void uart_set_irq(uart *uart_ptr, uint32_t ctrl_bits);

#endif
