# Build rules for HORNET programs. A program's Makefile only needs
#
#     PROG = blink            # optional, default: directory name
#     SRCS = main.c util.c    # optional, default: all *.c and *.S here
#     include ../../common.mk
#
# make            ELF, listing and the IMEM/DMEM images in build/ (also as imem.hex,
#                 dmem.hex and mem.cfg for the FPGA flow)
# make sim        run it on the SoC testbench (Verilator), SIM_ARGS="+timeout=<cycles> ..."
# make size       section sizes
# make clean
#
# On the host the compiler runs in the hornet-dev Docker image; inside the
# image (make shell) or with USE_DOCKER=0 it runs directly.

HORNET_SW   := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
HORNET_ROOT := $(abspath $(HORNET_SW)/..)

PROG      ?= $(notdir $(CURDIR))
SRCS      ?= $(wildcard *.c *.S)
OUT       ?= build
IMEM_SIZE ?= 0x10000
DMEM_SIZE ?= 0x10000
STACK_SIZE ?= 0x1000
# start of the program in IMEM and DMEM (the bootloader uses the top of both)
IMEM_ORIGIN ?= 0x0
DMEM_SKIP   ?= 0x0
OPT       ?= -O2
# core clock of the bitstream: 1000 MHz / CLK_DIV (large memories need more than 20)
CLK_DIV ?= 20
# 1: printf supports %f (larger program)
FLOAT_PRINTF ?= 0

# core configuration the program runs on: rv32i, rv32im or rv32imf.
# Without F, float code uses the soft-float library; without M, multiply and
# divide are library calls. REQUIRES = m and/or f in a program's Makefile
# marks programs that need an extension in hardware (run_sw_tests.py skips them).
ISA ?= rv32imf
ifeq ($(filter rv32i rv32im rv32imf,$(ISA)),)
$(error ISA=$(ISA): use rv32i, rv32im or rv32imf)
endif
REQUIRES ?=
MISSING := $(foreach e,$(REQUIRES),$(if $(findstring $(e),$(patsubst rv32i%,%,$(ISA))),,$(e)))
ifneq ($(MISSING),)
$(error $(PROG) needs the $(MISSING) extension, ISA=$(ISA) does not have it)
endif

RISCV_PREFIX ?= riscv32-unknown-elf-
MARCH ?= $(ISA)_zicsr_zifencei
MABI  ?= $(if $(findstring f,$(patsubst rv32i%,%,$(ISA))),ilp32f,ilp32)

IMAGE      ?= hornet-dev:latest
USE_DOCKER ?= $(if $(HORNET_CONTAINER),0,$(if $(shell command -v docker 2>/dev/null),1,0))
# a program outside this repository: SRC_ROOT (default: its directory) is mounted at its own path
OUT_OF_TREE := $(if $(filter $(HORNET_ROOT)/%,$(CURDIR)),,1)
SRC_ROOT    ?= $(CURDIR)
ifeq ($(USE_DOCKER),1)
ifeq ($(OUT_OF_TREE),1)
RUN = docker run --rm -u $(shell id -u):$(shell id -g) -v $(HORNET_ROOT):/work -v $(SRC_ROOT):$(SRC_ROOT) \
      -w $(CURDIR) -e HORNET_CONTAINER=1 $(IMAGE)
else
RUN = docker run --rm -u $(shell id -u):$(shell id -g) -v $(HORNET_ROOT):/work \
      -w /work/$(patsubst $(HORNET_ROOT)/%,%,$(CURDIR)) -e HORNET_CONTAINER=1 $(IMAGE)
endif
SW  = /work/sw
TOP = /work
else
RUN =
SW  = $(HORNET_SW)
TOP = $(HORNET_ROOT)
endif

DRIVERS = $(SW)/common/crt0.S $(SW)/common/syscalls.c $(SW)/drivers/uart.c $(SW)/drivers/gpio.c \
          $(SW)/drivers/timer.c $(SW)/drivers/irq.c

CFLAGS  += -march=$(MARCH) -mabi=$(MABI) $(OPT) -g -Wall -mstrict-align \
           -ffunction-sections -fdata-sections -I$(SW)/drivers
LDFLAGS += -nostartfiles -specs=nano.specs -T $(SW)/common/link.ld -Wl,--gc-sections \
           -Wl,--defsym=__imem_size=$(IMEM_SIZE) -Wl,--defsym=__dmem_size=$(DMEM_SIZE) \
           -Wl,--defsym=__stack_size=$(STACK_SIZE) -Wl,--defsym=__imem_origin=$(IMEM_ORIGIN) \
           -Wl,--defsym=__dmem_skip=$(DMEM_SKIP) -Wl,-Map=$(OUT)/$(PROG).map \
           -Wl,--no-warn-rwx-segments
ifeq ($(FLOAT_PRINTF),1)
LDFLAGS += -u _printf_float
endif
LIBS = -lm

ELF = $(OUT)/$(PROG).elf

.PHONY: all sim size clean

all: $(OUT)/$(PROG).imem.hex

# rebuild when the ISA, the memory layout or the optimisation changes (the images depend on them)
LAYOUT = $(OUT)/.layout-$(ISA)-$(IMEM_SIZE)-$(DMEM_SIZE)-$(STACK_SIZE)-$(IMEM_ORIGIN)-$(DMEM_SKIP)$(subst $() ,,$(OPT))
$(LAYOUT):
	@mkdir -p $(OUT)
	@rm -f $(OUT)/.layout-*
	@touch $@

$(ELF): $(SRCS) $(wildcard $(HORNET_SW)/drivers/*) $(wildcard $(HORNET_SW)/common/*) $(HORNET_SW)/common.mk Makefile $(LAYOUT)
	@mkdir -p $(OUT)
	$(RUN) $(RISCV_PREFIX)gcc $(CFLAGS) $(SRCS) $(DRIVERS) $(LDFLAGS) $(LIBS) -o $@

$(OUT)/$(PROG).imem.hex: $(ELF)
	$(RUN) sh -c '$(RISCV_PREFIX)objdump -d -S $< > $(OUT)/$(PROG).dump && \
	    python3 $(TOP)/scripts/elf2hex.py $< $(OUT)/$(PROG).imem.hex --base 0x0 --size $(IMEM_SIZE) --pad && \
	    python3 $(TOP)/scripts/elf2hex.py $< $(OUT)/$(PROG).dmem.hex --base 0x10000000 --size $(DMEM_SIZE) --pad && \
	    $(RISCV_PREFIX)size $<'
	cp $(OUT)/$(PROG).imem.hex $(OUT)/imem.hex
	cp $(OUT)/$(PROG).dmem.hex $(OUT)/dmem.hex
	echo "IMEM_SIZE=$$(($(IMEM_SIZE))) DMEM_SIZE=$$(($(DMEM_SIZE))) PROG=$(PROG) PROG_CLK_DIV=$(CLK_DIV) PROG_ISA=$(ISA)" > $(OUT)/mem.cfg

size: $(ELF)
	$(RUN) $(RISCV_PREFIX)size -A $<

SIM_ARGS ?=
sim: all
	$(MAKE) -C $(HORNET_ROOT) soc-sim ISA=$(ISA) HEX=$(if $(OUT_OF_TREE),$(abspath $(OUT)/$(PROG)),$(patsubst $(HORNET_ROOT)/%,%,$(abspath $(OUT)/$(PROG)))) \
	    IMEM_SIZE=$(IMEM_SIZE) DMEM_SIZE=$(DMEM_SIZE) $(if $(OUT_OF_TREE),EXTRA_MOUNT=$(SRC_ROOT)) SOC_ARGS="$(SIM_ARGS)"

clean:
	rm -rf $(OUT)
