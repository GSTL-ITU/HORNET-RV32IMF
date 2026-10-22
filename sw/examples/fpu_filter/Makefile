CC32=riscv64-unknown-elf
CCFLAGS=-march=rv32imf -mabi=ilp32f -ffp-contract=off -mstrict-align -malign-data=xlen -O3 -fno-math-errno -T ./linksc-10000.ld -lm -nostartfiles -ffunction-sections -fdata-sections -Wl,--gc-sections -o fpu_filter.elf


10K-CCFLAGS=-march=rv32imf -mabi=ilp32f -ffp-contract=off -mstrict-align -malign-data=xlen -Os -fno-math-errno -T ./linksc-10000.ld -lm -nostartfiles -ffunction-sections -fdata-sections -Wl,--gc-sections -g -ggdb -o fpu_filter.elf

build:
	$(CC32)-gcc fpu_filter.c ../../rom_gen/crt0.s $(CCFLAGS)
	$(CC32)-objcopy -O binary -j .init -j .text -j .rodata -j .sdata fpu_filter.elf fpu_filter.bin
	../../rom_gen/rom_generator fpu_filter.bin
	