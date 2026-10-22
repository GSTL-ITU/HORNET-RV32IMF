CC32=riscv32-unknown-elf
TARGET=sim_bubble_sort

CCFLAGS=-march=rv32imf -mabi=ilp32f -ffp-contract=off -mstrict-align -malign-data=xlen -O2 -fno-math-errno -T linksc.ld -nostartfiles -ffunction-sections -fdata-sections -Wl,--gc-sections -o $(TARGET).elf

build:
	$(CC32)-gcc main.c ../../rom_gen/crt0.s $(CCFLAGS)
	$(CC32)-objcopy -O binary -j .init -j .text -j .rodata -j .sdata $(TARGET).elf $(TARGET).bin
	
	../../rom_gen/rom_generator $(TARGET).bin
	
	cp $(TARGET).data memory_init.mem
	cp memory_init.mem ../../source/sim_1/imports/initialize_memory/memory_init_tb.mem

clean:
	rm -f *.elf *.bin *.data memory_init.mem