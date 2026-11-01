#include "irq.h"
//weak interrupt handler function definitions, to be overriden by the user.
void mei_handler() {}
void mti_handler() {}
void msi_handler() {}
void exc_handler() {}
void fast_irq0_handler() {}
void fast_irq1_handler() {}
void fast_irq2_handler() {}
void fast_irq3_handler() {}
void fast_irq4_handler() {}
void fast_irq5_handler() {}
void fast_irq6_handler() {}
void fast_irq7_handler() {}
void fast_irq8_handler() {}
void fast_irq9_handler() {}
void fast_irq10_handler() {}
void fast_irq11_handler() {}
void fast_irq12_handler() {}
void fast_irq13_handler() {}
void fast_irq14_handler() {}
void fast_irq15_handler() {}
void direct_trap_handler() {}

void SET_MTVEC_VECTOR_MODE()
{
    int base_addr;
    __asm__ volatile ("la %[base_addr],exc" :[base_addr] "=r" (base_addr): );
    base_addr |= 0x1; //vector mode
    __asm__ volatile ("csrw mtvec,%[base_addr]" :: [base_addr] "r" (base_addr));
}

void SET_MTVEC_DIRECT_MODE()
{
    int* base_addr;
    base_addr = (int*)&direct_trap_handler;
    __asm__ volatile ("csrw mtvec,%[base_addr]" :: [base_addr] "r" (base_addr));
}

//vector table: exceptions go to entry 0, interrupt n to entry n
__asm__(".section .text.vectors, \"ax\"\n.align 2\n");
__asm__("exc: j exc_handler\n");
__asm__("ssi: nop\n");
__asm__("hsi: nop\n");
__asm__("msi: j msi_handler\n");
__asm__("uti: nop\n");
__asm__("sti: nop\n");
__asm__("hti: nop\n");
__asm__("mti: j mti_handler\n");
__asm__("uei: nop\n");
__asm__("sei: nop\n");
__asm__("hei: nop\n");
__asm__("mei: j mei_handler\n");
__asm__("nop\n");
__asm__("nop\n");
__asm__("nop\n");
__asm__("nop\n");
__asm__("fast_irq0: j fast_irq0_handler\n");
__asm__("fast_irq1: j fast_irq1_handler\n");
__asm__("j fast_irq2_handler\nj fast_irq3_handler\nj fast_irq4_handler\nj fast_irq5_handler\n");
__asm__("j fast_irq6_handler\nj fast_irq7_handler\nj fast_irq8_handler\nj fast_irq9_handler\n");
__asm__("j fast_irq10_handler\nj fast_irq11_handler\nj fast_irq12_handler\nj fast_irq13_handler\n");
__asm__("j fast_irq14_handler\nj fast_irq15_handler\n");
__asm__(".text\n");
