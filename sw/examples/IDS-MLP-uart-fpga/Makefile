CC32=riscv32-unknown-elf
CCFLAGS=-march=rv32imf -mabi=ilp32f -ffp-contract=off -mstrict-align -malign-data=xlen -O3 -fno-math-errno -T ../linksc.ld -lm -nostartfiles -ffunction-sections -fdata-sections -Wl,--gc-sections -o inference_light_noBatch_FPGA.elf



build:
	$(CC32)-gcc inference_light_noBatch_FPGA.c ../../drivers/uart.c ../../drivers/irq.c ../../rom_gen/crt0.s $(CCFLAGS)
	$(CC32)-objcopy -O binary -j .init -j .text -j .rodata -j .sdata inference_light_noBatch_FPGA.elf inference_light_noBatch_FPGA.bin
	../../rom_gen/rom_generator inference_light_noBatch_FPGA.bin
	cp inference_light_noBatch_FPGA.data memory_init.mem

comp:
	gcc inference_light_noBatch_FPGA.c -lm -o inference_light_noBatch_FPGA