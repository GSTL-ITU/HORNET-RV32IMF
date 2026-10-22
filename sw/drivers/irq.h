#ifndef IRQ_H
#define IRQ_H

#define ENABLE_GLOBAL_IRQ() __asm__ volatile ("csrsi mstatus,0x8\n"); //enables interrupts globally by setting the mie bit in mstatus register.
#define DISABLE_GLOBAL_IRQ() __asm__ volatile ("csrci mstatus,0x8\n"); //disables interrupts globally by clearing the mie bit in mstatus register.

// Fast interrupt lines (mip/mie bits 16..31)
#define FAST_IRQ_UART 0
#define FAST_IRQ_GPIO 1
// fast interrupts 2..15 are the irq_i pins of hornet_soc

//interrupt routines for vectored mode.
void mei_handler() __attribute__ (( weak, interrupt ("machine")));
void mti_handler() __attribute__ (( weak, interrupt ("machine")));
void msi_handler() __attribute__ (( weak, interrupt ("machine")));
void exc_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq0_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq1_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq2_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq3_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq4_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq5_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq6_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq7_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq8_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq9_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq10_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq11_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq12_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq13_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq14_handler() __attribute__ (( weak, interrupt ("machine")));
void fast_irq15_handler() __attribute__ (( weak, interrupt ("machine")));
//trap handler for direct mode.
void direct_trap_handler() __attribute__ (( weak, interrupt ("machine")));

//sets mtvec's value to the beginning of the vector table, and sets the LSB.
void SET_MTVEC_VECTOR_MODE();

//sets mtvec's value to the address of the trap handler function.
void SET_MTVEC_DIRECT_MODE();

//enables machine level timer interrupts by setting the mtie bit in mie register.
static inline void ENABLE_MTI()
{
    int mask = 0x80;
    __asm__ volatile ("csrs mie,%[mask]" :: [mask] "r" (mask));
}

//disables machine level timer interrupts by clearing the mtie bit in mie register.
static inline void DISABLE_MTI()
{
    int mask = 0x80;
    __asm__ volatile ("csrc mie,%[mask]" :: [mask] "r" (mask));
}

//enables machine level software interrupts by setting the msie bit in mie register.
static inline void ENABLE_MSI()
{
    int mask = 0x8;
    __asm__ volatile ("csrs mie,%[mask]" :: [mask] "r" (mask));
}

//disables machine level software interrupts by clearing the msie bit in mie register.
static inline void DISABLE_MSI()
{
    int mask = 0x8;
    __asm__ volatile ("csrc mie,%[mask]" :: [mask] "r" (mask));
}

//enables machine level external interrupts by setting the meie bit in mie register.
static inline void ENABLE_MEI()
{
    int mask = 0x800;
    __asm__ volatile ("csrs mie,%[mask]" :: [mask] "r" (mask));
}
//disables machine level external interrupts by clearing the meie bit in mie register.
static inline void DISABLE_MEI()
{
    int mask = 0x800;
    __asm__ volatile ("csrc mie,%[mask]" :: [mask] "r" (mask));
}

//enables fast interrupts by setting the associated bit in mie register.
static inline void ENABLE_FAST_IRQ(int irq_index)
{
    int mask = 0x1 << (irq_index+16);
    __asm__ volatile ("csrs mie,%[mask]" :: [mask] "r" (mask));
}
//disables fast interrupts by clearing the associated bit in mie register.
static inline void DISABLE_FAST_IRQ(int irq_index)
{
    int mask = 0x1 << (irq_index+16);
    __asm__ volatile ("csrc mie,%[mask]" :: [mask] "r" (mask));
}

#endif
