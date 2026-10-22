PROG = inference_light_noBatch_FPGA
SRCS = inference_light_noBatch_FPGA.c
# the weights need about 300 KB: 320 KB IMEM (80 of the 135 BRAM36 of the Artix-7 100T)
IMEM_SIZE = 0x50000
# 320 KB of block RAM spreads over the device: 41.7 MHz (1000 MHz / 24)
CLK_DIV = 24
include ../../common.mk


# Runs the first SAMPLES test vectors through the SoC testbench and compares
# the answers with the FPGA results in test/label_results.txt
SAMPLES ?= 6
check: all
	$(RUN) python3 test/make_uart_in.py test/inputs.txt $(SAMPLES) $(OUT)/uart_in.bin
	$(MAKE) -s -C $(HORNET_ROOT) soc-sim HEX=$(patsubst $(HORNET_ROOT)/%,%,$(abspath $(OUT)/$(PROG))) \
	    IMEM_SIZE=$(IMEM_SIZE) DMEM_SIZE=$(DMEM_SIZE) \
	    SOC_ARGS="+uart_in=$(patsubst $(HORNET_ROOT)/%,%,$(abspath $(OUT)/uart_in.bin)) +uart_in_block=488 +uart_in_wait=1 +uart_hex +timeout=$$(( $(SAMPLES) * 1600000 + 2000000 ))" \
	    > $(OUT)/check.log || true
	$(RUN) python3 test/check_sim.py $(OUT)/check.log test/label_results.txt
