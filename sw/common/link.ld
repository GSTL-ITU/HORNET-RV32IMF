/* HORNET linker script: code and constants in IMEM, data, heap and stack in DMEM.
   Sizes come from common.mk (--defsym __imem_size / __dmem_size); both images
   are loaded into the block RAMs, so .data needs no copy at boot. */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = __imem_size
    DMEM (rw)  : ORIGIN = 0x10000000, LENGTH = __dmem_size
}

__stack_size = DEFINED(__stack_size) ? __stack_size : 0x1000;

SECTIONS
{
    .text :
    {
        KEEP(*(.init))
        *(.text.unlikely .text.unlikely.*)
        *(.text.startup .text.startup.*)
        *(.text .text.*)
    } > IMEM

    .rodata :
    {
        . = ALIGN(4);
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        . = ALIGN(4);
        __init_array_start = .;
        KEEP(*(SORT_BY_INIT_PRIORITY(.init_array.*)))
        KEEP(*(.init_array))
        __init_array_end = .;
        __fini_array_start = .;
        KEEP(*(.fini_array))
        __fini_array_end = .;
        . = ALIGN(4);
    } > IMEM

    .data :
    {
        . = ALIGN(4);
        *(.data .data.*)
    } > DMEM

    .sdata :
    {
        . = ALIGN(4);
        __global_pointer$ = . + 0x800;
        *(.sdata .sdata.*)
    } > DMEM

    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        __bss_start = .;
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > DMEM

    . = ALIGN(16);
    _end = .;
    __heap_start = .;
    __stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
    __heap_end = __stack_top - __stack_size;
    ASSERT(__heap_start <= __heap_end, "DMEM too small for data, bss and stack")

    /DISCARD/ : { *(.eh_frame .eh_frame_hdr .comment .note .note.* .riscv.attributes) }
}
