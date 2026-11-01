// Interrupts and exceptions: direct-mode traps, then vectored timer, software,
// UART RX, GPIO, fast-pin and external interrupts (pins looped back in tb/soc_tb.sv)
#include <stdio.h>
#include "hornet.h"
#include "irq.h"
#include "timer.h"
#include "gpio.h"
#include "uart.h"

volatile int ecalls, illegals, mti, msi, uart_rx, gpio, fast4, mei;
volatile uint32_t last_cause;
volatile char rx[4];

void direct_trap_handler()
{
    uint32_t cause = read_csr(mcause);
    last_cause = cause;
    if (cause == 11)
        ecalls++;
    else if (cause == 2)
        illegals++;
    write_csr(mepc, read_csr(mepc) + 4);
}

void mti_handler() { mti++; timer_set_compare(~0ull); }
void msi_handler() { msi++; timer_software_irq(0); }
void fast_irq0_handler() { rx[uart_rx & 3] = uart_receive_byte(&uart0); uart_rx++; }
void fast_irq1_handler() { gpio++; gpio_irq_clear(1u << 5); }
void fast_irq4_handler() { fast4++; gpio_clear_pin(18); }
void mei_handler() { mei++; gpio_clear_pin(31); }

static int check(const char *what, int got, int want)
{
    printf("%-10s %d %s\n", what, got, got == want ? "ok" : "FAILED");
    return got == want ? 0 : 1;
}

int main(void)
{
    int errors = 0;

    SET_MTVEC_DIRECT_MODE();
    __asm__ volatile ("ecall");
    __asm__ volatile ("ecall");
    __asm__ volatile (".word 0");
    errors += check("ecall", ecalls, 2);
    errors += check("illegal", illegals, 1);

    SET_MTVEC_VECTOR_MODE();
    gpio_set_dir(0xffff0000u);
    ENABLE_GLOBAL_IRQ();

    ENABLE_MTI();
    timer_set_alarm(500);
    while (!mti)
        ;
    DISABLE_MTI();
    errors += check("timer", mti, 1);

    ENABLE_MSI();
    timer_software_irq(1);
    for (volatile int i = 0; i < 10; i++)
        ;
    DISABLE_MSI();
    errors += check("software", msi, 1);

    gpio_irq_enable(1u << 5, 0);
    ENABLE_FAST_IRQ(FAST_IRQ_GPIO);
    gpio_set_pin(5);
    for (volatile int i = 0; i < 20; i++)
        ;
    gpio_clear_pin(5);
    errors += check("gpio", gpio, 1);

    ENABLE_FAST_IRQ(4);
    gpio_set_pin(18);
    for (volatile int i = 0; i < 20; i++)
        ;
    errors += check("fast_irq4", fast4, 1);

    ENABLE_MEI();
    gpio_set_pin(31);
    for (volatile int i = 0; i < 20; i++)
        ;
    errors += check("external", mei, 1);

    uart_set_irq(&uart0, UART_RX_IRQ);
    ENABLE_FAST_IRQ(FAST_IRQ_UART);
    while (uart_rx < 3)
        ;
    errors += check("uart_rx", uart_rx, 3);
    errors += check("uart_data", rx[0] == 'H' && rx[1] == 'i' && rx[2] == '!', 1);

    DISABLE_GLOBAL_IRQ();
    return errors;
}
