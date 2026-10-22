// newlib system calls: stdout/stdin on UART0, heap in DMEM, exit to the system control register
#include <errno.h>
#include <stdint.h>
#include <sys/stat.h>
#include "uart.h"

extern char __heap_start[], __heap_end[];
static char *heap = __heap_start;

void *_sbrk(intptr_t incr)
{
    if (heap + incr > __heap_end) {
        errno = ENOMEM;
        return (void *)-1;
    }
    char *prev = heap;
    heap += incr;
    return prev;
}

int _write(int fd, const char *buf, int len)
{
    (void)fd;
    for (int i = 0; i < len; i++) {
        if (buf[i] == '\n')
            uart_transmit_byte(&uart0, '\r');
        uart_transmit_byte(&uart0, buf[i]);
    }
    return len;
}

int _read(int fd, char *buf, int len)
{
    (void)fd;
    if (len <= 0)
        return 0;
    buf[0] = uart_receive_byte(&uart0);
    return 1;
}

void _exit(int code)
{
    uart_wait_tx_idle(&uart0);
    hornet_exit((uint32_t)code);
    for (;;)
        __asm__ volatile ("wfi");
}

int _close(int fd) { (void)fd; return -1; }
int _fstat(int fd, struct stat *st) { (void)fd; st->st_mode = S_IFCHR; return 0; }
int _isatty(int fd) { (void)fd; return 1; }
int _lseek(int fd, int off, int dir) { (void)fd; (void)off; (void)dir; return 0; }
int _kill(int pid, int sig) { (void)pid; (void)sig; errno = EINVAL; return -1; }
int _getpid(void) { return 1; }

static void put_hex(uint32_t v)
{
    for (int i = 28; i >= 0; i -= 4)
        uart_transmit_byte(&uart0, "0123456789abcdef"[(v >> i) & 0xf]);
}

// Default handler for traps nobody expected (mtvec set by crt0)
__attribute__((weak)) void hornet_trap(uint32_t mcause, uint32_t mepc, uint32_t mtval)
{
    uart_puts(&uart0, "\r\nTRAP mcause=");
    put_hex(mcause);
    uart_puts(&uart0, " mepc=");
    put_hex(mepc);
    uart_puts(&uart0, " mtval=");
    put_hex(mtval);
    uart_puts(&uart0, "\r\n");
    _exit(0x100 | (mcause & 0xff));
}
