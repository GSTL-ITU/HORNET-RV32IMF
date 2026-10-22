CC32=riscv32-unknown-elf
CCFLAGS=-march=rv32imf -mabi=ilp32f -ffp-contract=off -mstrict-align -malign-data=xlen -O3 -fno-math-errno -T linksc.ld -lm -nostartfiles -ffunction-sections -fdata-sections -Wl,--gc-sections -o gpio_test.elf

build:
	$(CC32)-gcc main.c ../../drivers/gpio.c ../../rom_gen/crt0.s $(CCFLAGS)
	$(CC32)-objcopy -O binary -j .init -j .text -j .rodata -j .sdata gpio_test.elf gpio_test.bin
	
	../../rom_gen/rom_generator gpio_test.bin
	
	cp gpio_test.data memory_init.mem
	cp memory_init.mem ../../source/sources_1/imports/initialize_memory/memory_init.mem

clean:
	rm -f *.elf *.bin *.data memory_init.mem