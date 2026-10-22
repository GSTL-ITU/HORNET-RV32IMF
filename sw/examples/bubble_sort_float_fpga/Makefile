CC32=riscv32-unknown-elf
CCFLAGS=-march=rv32imf -mabi=ilp32f -ffp-contract=off -mstrict-align -malign-data=xlen -O3 -fno-math-errno -T linksc.ld -nostartfiles -ffunction-sections -fdata-sections -Wl,--gc-sections -o bubble_sort.elf

build:
	$(CC32)-gcc main.c ../../drivers/gpio.c ../../rom_gen/crt0.s $(CCFLAGS)
	$(CC32)-objcopy -O binary -j .init -j .text -j .rodata -j .sdata bubble_sort.elf bubble_sort.bin
	
	../../rom_gen/rom_generator bubble_sort.bin
	
	cp bubble_sort.data memory_init.mem
	cp memory_init.mem ../../source/sources_1/imports/initialize_memory/memory_init.mem

clean:
	rm -f *.elf *.bin *.data memory_init.mem