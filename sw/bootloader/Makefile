# Bootloader for the top 4 KB of IMEM; IMEM_SIZE and DMEM_SIZE must match the bitstream.
PROG = bootloader
IMEM_SIZE ?= 0x10000
DMEM_SIZE ?= 0x10000
IMEM_ORIGIN = $(shell printf '0x%x' $$(($(IMEM_SIZE) - 0x1000)))
DMEM_SKIP   = $(shell printf '0x%x' $$(($(DMEM_SIZE) - 0x400)))
STACK_SIZE  = 0x300
OPT = -Os
include ../common.mk
