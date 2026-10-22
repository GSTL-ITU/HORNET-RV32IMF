# HORNET startup: stack, gp, FPU on, trap vector, .bss, constructors, main, exit
    .section .init, "ax"
    .global _start
_start:
    .cfi_startproc
    .cfi_undefined ra
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop
    la sp, __stack_top
    add s0, sp, zero

    li t0, 0x2000            # mstatus.FS = Initial
    csrs mstatus, t0
    csrwi fcsr, 0
    la t0, __trap_entry
    csrw mtvec, t0

    la a0, __bss_start       # .data is in the DMEM image, only .bss is cleared
    la a1, __bss_end
1:  bgeu a0, a1, 2f
    sw zero, 0(a0)
    addi a0, a0, 4
    j 1b
2:
    la s1, __init_array_start
    la s2, __init_array_end
3:  bgeu s1, s2, 4f
    lw t0, 0(s1)
    jalr t0
    addi s1, s1, 4
    j 3b
4:
    li a0, 0
    li a1, 0
    call main
    call exit
5:  j 5b
    .cfi_endproc

# unexpected traps end in hornet_trap() (weak, in syscalls.c)
    .weak __trap_entry
    .align 2
__trap_entry:
    csrr a0, mcause
    csrr a1, mepc
    csrr a2, mtval
    la sp, __stack_top
    call hornet_trap
6:  j 6b
