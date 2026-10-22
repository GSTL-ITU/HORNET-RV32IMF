# HORNET top-level Makefile.
#
# Every tool except Vivado runs inside the Docker image (make docker-build).
# On the host the commands are wrapped in `docker run`; inside the container
# (make shell, devcontainer, CI) they run directly.

IMAGE   ?= hornet-dev:latest
DOCKER  ?= docker
# limits for a laptop: parallel jobs and container memory
JOBS    ?= 4
MEMLIM  ?= 8g

ifdef HORNET_CONTAINER
DOCKER_RUN  =
else
DOCKER_RUN  = $(DOCKER) run --rm -t --memory=$(MEMLIM) -u $(shell id -u):$(shell id -g) \
              -v $(CURDIR):/work -w /work $(IMAGE)
endif

BUILD   ?= build

CORE_SRCS = rtl/core/hornet_core.v rtl/core/if_stage.v rtl/core/id_stage.v rtl/core/ex_stage.v \
            rtl/core/mem_stage.v rtl/core/wb_stage.v rtl/core/hazard_unit.v rtl/core/csr_unit.v \
            rtl/core/regfile.v rtl/core/control_unit.v rtl/core/imm_decoder.v rtl/core/ALU.v \
            rtl/core/mul.v rtl/core/div.v
FPU_SRCS  = rtl/fpu/fpu_top.v rtl/fpu/fpu_fma.v rtl/fpu/fpu_divsqrt.v rtl/fpu/fpu_cvt.v rtl/fpu/fpu_round.v \
            rtl/fpu/fpu_decoder.v rtl/fpu/fpu_sign_inj.v rtl/fpu/fpu_min_max.v rtl/fpu/fpu_compare.v \
            rtl/fpu/fpu_classifier.v
SOC_SRCS  = rtl/soc/hornet_soc.v rtl/soc/imem.v rtl/soc/dmem.v rtl/soc/data_router.v rtl/soc/obi_axil_bridge.v \
            rtl/soc/axil_xbar.v rtl/soc/axil_timer.v rtl/soc/axil_uart.v rtl/soc/axil_gpio.v rtl/soc/sync_fifo.v \
            rtl/soc/axil_sysctl.v
RTL_SRCS  = $(CORE_SRCS) $(FPU_SRCS)
RTL_INC   = -Irtl/core -Irtl/fpu

SIM        = $(BUILD)/sim/core/Vhornet_tb
SIM_FPU    = $(BUILD)/sim/fpu/Vfpu_tb
VERILATOR_FLAGS = --binary --timing -j $(JOBS) -Wno-fatal -Wno-lint -Wno-style +1364-2005ext+v \
                  --trace-fst --timescale 1ns/1ps $(RTL_INC)

RISCV_TESTS  = verif/riscv-tests/isa/rv32ui/Makefrag
RISCV_FORMAL = verif/riscv-formal/checks/genchecks.py

SUITES    ?= ui,um,uf,mi
TEST_ARGS ?=
MEM_STALL ?= 30
RANDOM    ?= 200
SEED      ?= 1

# riscv-formal: parallel checks, timeout per check in seconds, optional subset
FORMAL_JOBS    ?= 6
FORMAL_TIMEOUT ?= 2400
FORMAL_CHECKS  ?=

.PHONY: help docker-build shell tool-versions lint sim test cosim cosim-stall random fpu-test formal soc-sim sw-tests boot-test regress clean \
        fpga-build fpga-program fpga-project fpga-ip fpga-bd

help:
	@echo "make docker-build   Build the $(IMAGE) image"
	@echo "make shell          Interactive shell in the image"
	@echo "make lint           Verilator lint of the RTL (Verilog-2005)"
	@echo "make sim            Build the core testbench"
	@echo "make test           riscv-tests ($(SUITES)) on the core"
	@echo "make cosim          The same, compared with Spike"
	@echo "make cosim-stall    cosim with random memory wait states (MEM_STALL=$(MEM_STALL))"
	@echo "make fpu-test       FPU alone against TestFloat vectors (all rounding modes)"
	@echo "make random         RANDOM=$(RANDOM) random programs vs. Spike, plain and with wait states"
	@echo "make formal         riscv-formal on the RVFI port (FORMAL_JOBS=$(FORMAL_JOBS), FORMAL_CHECKS=\"reg_ch0 ...\")"
	@echo "make soc-sim HEX=<path/prog>  Run <prog>.imem.hex/.dmem.hex on the SoC testbench"
	@echo "make sw-tests       Build and run the SoC test programs in sw/tests"
	@echo "make boot-test      The UART bootloader loads and runs a program (simulation)"
	@echo "make regress        Everything above plus formal"
	@echo "make fpga-build FPGA_PROG=sw/examples/gpio   Bitstream with that program in the BRAMs (Vivado, host)"
	@echo "                    BOOTLOADER=1 adds the UART bootloader (scripts/hornet_load.py loads programs)"
	@echo "make fpga-program FPGA_PROG=...               Program the board over JTAG"
	@echo "make fpga-project FPGA_PROG=...               Vivado GUI project in $(BUILD)/fpga/project"
	@echo "make fpga-ip        Package hornet_soc as a Vivado IP (m_axi AXI4-Lite master) in $(BUILD)/ip"
	@echo "make fpga-bd        Block-design demo: HORNET IP + Xilinx AXI GPIO, to a bitstream"
	@echo "make clean          Remove $(BUILD)/"

docker-build:
	$(DOCKER) build --build-arg JOBS=$(JOBS) -t $(IMAGE) docker

shell:
	$(DOCKER) run --rm -it --memory=$(MEMLIM) -u $(shell id -u):$(shell id -g) -v $(CURDIR):/work -w /work $(IMAGE) bash

tool-versions:
	$(DOCKER_RUN) sh -c 'verilator --version; riscv32-unknown-elf-gcc --version | head -1; spike --help 2>&1 | head -1; yosys -V; python3 --version'

$(RISCV_TESTS):
	git submodule update --init verif/riscv-tests
	git -C verif/riscv-tests submodule update --init env

$(RISCV_FORMAL):
	git submodule update --init verif/riscv-formal

lint:
	$(DOCKER_RUN) verilator --lint-only -Wall --language 1364-2005 $(RTL_INC) --top-module hornet_core \
	    rtl/lint.vlt $(RTL_SRCS)
	$(DOCKER_RUN) verilator --lint-only -Wall --language 1364-2005 $(RTL_INC) --top-module hornet_soc \
	    rtl/lint.vlt $(RTL_SRCS) $(SOC_SRCS)

sim: $(SIM)

$(SIM): $(RTL_SRCS) tb/hornet_tb.sv
	@mkdir -p $(@D)
	$(DOCKER_RUN) verilator $(VERILATOR_FLAGS) --top-module hornet_tb --Mdir $(@D) -o $(@F) \
	    $(RTL_SRCS) tb/hornet_tb.sv > $(@D).log
	@echo "Built $@"

$(SIM_FPU): $(FPU_SRCS) tb/fpu_tb.sv
	@mkdir -p $(@D)
	$(DOCKER_RUN) verilator $(VERILATOR_FLAGS) --top-module fpu_tb --Mdir $(@D) -o $(@F) \
	    $(FPU_SRCS) tb/fpu_tb.sv > $(@D).log
	@echo "Built $@"

$(BUILD)/fpu/vectors.txt: scripts/fpu_vectors.py
	@mkdir -p $(@D)
	$(DOCKER_RUN) python3 scripts/fpu_vectors.py --out $@

fpu-test: $(SIM_FPU) $(BUILD)/fpu/vectors.txt
	$(DOCKER_RUN) sh -c '$(SIM_FPU) +vectors=$(BUILD)/fpu/vectors.txt | tee $(BUILD)/fpu/fpu_test.log | grep -v "^- "'
	@grep -q "^PASS" $(BUILD)/fpu/fpu_test.log

IMEM_SIZE ?= 0x10000
DMEM_SIZE ?= 0x10000
BOOT_ADDR ?= 0x0
SIM_SOC    = $(BUILD)/sim/soc-$(IMEM_SIZE)-$(DMEM_SIZE)-$(BOOT_ADDR)/Vsoc_tb
$(SIM_SOC): $(RTL_SRCS) $(SOC_SRCS) tb/soc_tb.sv
	@mkdir -p $(@D)
	$(DOCKER_RUN) verilator $(VERILATOR_FLAGS) --top-module soc_tb --Mdir $(@D) -o $(@F) \
	    -GIMEM_SIZE=$$(($(IMEM_SIZE))) -GDMEM_SIZE=$$(($(DMEM_SIZE))) -GBOOT_ADDR=$$(($(BOOT_ADDR))) $(RTL_SRCS) $(SOC_SRCS) tb/soc_tb.sv > $(@D).log
	@echo "Built $@"

SOC_ARGS ?=
soc-sim: $(SIM_SOC)
	$(DOCKER_RUN) sh -c '$(SIM_SOC) +imem=$(HEX).imem.hex +dmem=$(HEX).dmem.hex +uart_log=$(HEX).uart.log $(SOC_ARGS) | grep -v "^- "'

sw-tests: $(SIM_SOC)
	$(DOCKER_RUN) python3 scripts/run_sw_tests.py --sim $(SIM_SOC) -j $(JOBS)

# the bootloader alone in IMEM loads sw/tests/hello over the UART and runs it
boot-test:
	$(MAKE) -s -C sw/bootloader
	$(MAKE) -s -C sw/tests/hello
	$(DOCKER_RUN) python3 scripts/hornet_load.py --emit sw/bootloader/build/hello.bin sw/tests/hello/build/hello.elf
	$(MAKE) -s soc-sim BOOT_ADDR=0xf000 HEX=sw/bootloader/build/bootloader \
	    SOC_ARGS="+uart_in=sw/bootloader/build/hello.bin +timeout=3000000" | tee $(BUILD)/boot-test.log
	@grep -q "^PASS" $(BUILD)/boot-test.log

test: $(SIM) $(RISCV_TESTS)
	$(DOCKER_RUN) python3 scripts/run_tests.py --sim $(SIM) --suites $(SUITES) -j $(JOBS) $(TEST_ARGS)

cosim: $(SIM) $(RISCV_TESTS)
	$(DOCKER_RUN) python3 scripts/run_tests.py --sim $(SIM) --suites $(SUITES) --spike -j $(JOBS) $(TEST_ARGS)

cosim-stall: $(SIM) $(RISCV_TESTS)
	$(DOCKER_RUN) python3 scripts/run_tests.py --sim $(SIM) --suites $(SUITES) --spike -j $(JOBS) \
	    --mem-stall $(MEM_STALL) --workdir $(BUILD)/tests-stall $(TEST_ARGS)

random: $(SIM)
	$(DOCKER_RUN) python3 scripts/run_tests.py --sim $(SIM) --spike -j $(JOBS) --random $(RANDOM) \
	    --seed $(SEED) --workdir $(BUILD)/random
	$(DOCKER_RUN) python3 scripts/run_tests.py --sim $(SIM) --spike -j $(JOBS) --random $(RANDOM) \
	    --seed $(SEED) --mem-stall $(MEM_STALL) --workdir $(BUILD)/random-stall

formal: $(RISCV_FORMAL)
	$(DOCKER_RUN) env FORMAL_TIMEOUT=$(FORMAL_TIMEOUT) scripts/run_formal.sh $(BUILD) $(FORMAL_JOBS) $(FORMAL_CHECKS)

regress: lint fpu-test cosim cosim-stall random formal

# ------------------------------------------------------------------ FPGA (Vivado on the host)
VIVADO    ?= $(shell command -v vivado 2>/dev/null || echo /opt/Xilinx/2025.2/Vivado/bin/vivado)
FPGA_PROG ?= sw/examples/gpio
CLK_DIV   ?= 20
FPGA_OUT   = $(BUILD)/fpga/$(notdir $(FPGA_PROG))

# BOOTLOADER=1 adds sw/bootloader at the top of IMEM and starts there
BOOTLOADER ?= 0
fpga-build:
	$(MAKE) -C $(FPGA_PROG)
	@mkdir -p $(FPGA_OUT)
	. $(FPGA_PROG)/build/mem.cfg && \
	if [ "$(BOOTLOADER)" = 1 ]; then \
	    $(MAKE) -s -C sw/bootloader IMEM_SIZE=$$IMEM_SIZE DMEM_SIZE=$$DMEM_SIZE OUT=build/$$IMEM_SIZE-$$DMEM_SIZE && \
	    boot=sw/bootloader/build/$$IMEM_SIZE-$$DMEM_SIZE/bootloader.elf && \
	    $(DOCKER_RUN) sh -c "python3 scripts/elf2hex.py $$boot $(FPGA_PROG)/build/$$PROG.elf $(FPGA_OUT)/imem.hex --base 0 --size $$IMEM_SIZE --pad && \
	        python3 scripts/elf2hex.py $$boot $(FPGA_PROG)/build/$$PROG.elf $(FPGA_OUT)/dmem.hex --base 0x10000000 --size $$DMEM_SIZE --pad" && \
	    BOOT_ADDR=$$(($$IMEM_SIZE - 0x1000)); \
	else \
	    cp $(FPGA_PROG)/build/imem.hex $(FPGA_PROG)/build/dmem.hex $(FPGA_OUT)/ && BOOT_ADDR=0; \
	fi && \
	cd $(FPGA_OUT) && $(VIVADO) -mode batch -nojournal -log vivado.log \
	    -source $(CURDIR)/fpga/nexys4ddr/build.tcl -tclargs . $(CURDIR)/$(FPGA_OUT)/imem.hex \
	    $(CURDIR)/$(FPGA_OUT)/dmem.hex $$IMEM_SIZE $$DMEM_SIZE $(CLK_DIV) $$BOOT_ADDR > /dev/null; \
	    grep "^RESULT" vivado.log

fpga-program:
	$(VIVADO) -mode batch -nojournal -nolog -source fpga/nexys4ddr/program.tcl -tclargs $(FPGA_OUT)/hornet_nexys4ddr.bit

fpga-project:
	$(MAKE) -C $(FPGA_PROG)
	@mkdir -p $(BUILD)/fpga
	. $(FPGA_PROG)/build/mem.cfg && cd $(BUILD)/fpga && $(VIVADO) -mode batch -nojournal -log project.log \
	    -source $(CURDIR)/fpga/nexys4ddr/create_project.tcl -tclargs project $(CURDIR)/$(FPGA_PROG)/build/imem.hex \
	    $(CURDIR)/$(FPGA_PROG)/build/dmem.hex $$IMEM_SIZE $$DMEM_SIZE $(CLK_DIV)

fpga-ip:
	@mkdir -p $(BUILD)/ip
	cd $(BUILD)/ip && $(VIVADO) -mode batch -nojournal -log package.log -source $(CURDIR)/fpga/ip/package_ip.tcl \
	    -tclargs . > /dev/null; grep "^RESULT" package.log

BD_PROG ?= sw/examples/axi_gpio
fpga-bd: fpga-ip
	$(MAKE) -C $(BD_PROG)
	@mkdir -p $(BUILD)/fpga/bd
	cd $(BUILD)/fpga/bd && $(VIVADO) -mode batch -nojournal -log vivado.log -source $(CURDIR)/fpga/ip/bd_demo.tcl \
	    -tclargs . $(CURDIR)/$(BUILD)/ip $(CURDIR)/$(BD_PROG)/build/imem.hex $(CURDIR)/$(BD_PROG)/build/dmem.hex > /dev/null; \
	    grep "^RESULT" vivado.log

clean:
	rm -rf $(BUILD)
